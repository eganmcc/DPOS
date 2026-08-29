package id.co.ptdika.dpos

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val spp: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    // Instant scanner beep via the system ToneGenerator (no asset, no audio
    // warm-up / queuing — the audioplayers path was unreliable for rapid scans).
    private var toneGen: ToneGenerator? = null

    private fun ensureTone() {
        if (toneGen == null) {
            try {
                toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 90)
            } catch (_: Exception) {
            }
        }
    }

    private fun scanBeep() {
        ensureTone()
        try {
            toneGen?.startTone(ToneGenerator.TONE_CDMA_PIP, 120)
        } catch (_: Exception) {
        }
    }

    // Native ESC/POS bytes over classic Bluetooth SPP. Tries an INSECURE RFCOMM
    // socket first (cheap thermal printers like RPP02N reject the secure one that
    // the print_bluetooth_thermal plugin uses), then secure, then the reflection
    // channel-1 fallback.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dpos/printer")
            .setMethodCallHandler { call, result ->
                if (call.method == "beep") {
                    scanBeep()
                    result.success(true)
                } else if (call.method == "warmupBeep") {
                    ensureTone()
                    result.success(true)
                } else if (call.method == "printBytes") {
                    val mac = call.argument<String>("mac")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (mac == null || bytes == null) {
                        result.success(false)
                    } else {
                        Thread {
                            val ok = printBytes(mac, bytes)
                            Handler(Looper.getMainLooper()).post { result.success(ok) }
                        }.start()
                    }
                } else if (call.method == "printBytesRongta") {
                    // SEPARATE Rongta RP58 path — does not touch printBytes above.
                    val mac = call.argument<String>("mac")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (mac == null || bytes == null) {
                        result.success(false)
                    } else {
                        Thread {
                            val ok = printBytesRongta(mac, bytes)
                            Handler(Looper.getMainLooper()).post { result.success(ok) }
                        }.start()
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun printBytes(mac: String, bytes: ByteArray): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        val device: BluetoothDevice = try {
            adapter.getRemoteDevice(mac)
        } catch (e: Exception) {
            return false
        }
        try {
            adapter.cancelDiscovery()
        } catch (_: Exception) {
        }

        val makers: List<() -> BluetoothSocket?> = listOf(
            { device.createInsecureRfcommSocketToServiceRecord(spp) },
            { device.createRfcommSocketToServiceRecord(spp) },
            {
                val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                m.invoke(device, 1) as BluetoothSocket
            },
        )

        for (make in makers) {
            var socket: BluetoothSocket? = null
            try {
                socket = make() ?: continue
                socket.connect()
                val out = socket.outputStream
                out.write(bytes)
                out.flush()
                Thread.sleep(600) // let the printer drain before we close the socket
                try {
                    socket.close()
                } catch (_: Exception) {
                }
                return true
            } catch (e: Exception) {
                try {
                    socket?.close()
                } catch (_: Exception) {
                }
                // fall through to the next connection method
            }
        }
        return false
    }

    // SEPARATE path for the Rongta RP58 (does NOT modify printBytes above).
    // Differences that address "connects but nothing prints":
    //  - SDP-resolved sockets ONLY (secure first, then insecure) — the correct
    //    RFCOMM channel is discovered, never the hard-coded channel-1 reflection
    //    hack (the prime suspect for a silent no-print).
    //  - Chunked writes + a generous drain before close (Android BluetoothSocket
    //    flush() is a no-op; closing too early truncates the job on a slower/
    //    small-buffer printer).
    //  - Logs which connector actually worked (adb logcat -s RongtaPrint).
    private fun printBytesRongta(mac: String, bytes: ByteArray): Boolean {
        val tag = "RongtaPrint"
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: run {
            Log.w(tag, "no bluetooth adapter")
            return false
        }
        val device: BluetoothDevice = try {
            adapter.getRemoteDevice(mac)
        } catch (e: Exception) {
            Log.w(tag, "bad mac $mac: ${e.message}")
            return false
        }
        Log.i(tag, "device=${device.name} mac=$mac bond=${device.bondState} bytes=${bytes.size}")
        try {
            adapter.cancelDiscovery()
        } catch (_: Exception) {
        }

        val makers: List<Pair<String, () -> BluetoothSocket?>> = listOf(
            "secure-sdp" to { device.createRfcommSocketToServiceRecord(spp) },
            "insecure-sdp" to { device.createInsecureRfcommSocketToServiceRecord(spp) },
        )

        for ((label, make) in makers) {
            var socket: BluetoothSocket? = null
            try {
                socket = make() ?: continue
                socket.connect()
                Log.i(tag, "connected via $label")
                val out = socket.outputStream
                // Chunked write so a small-buffer printer isn't overrun.
                var off = 0
                val chunk = 256
                while (off < bytes.size) {
                    val end = minOf(off + chunk, bytes.size)
                    out.write(bytes, off, end - off)
                    out.flush()
                    off = end
                    Thread.sleep(20)
                }
                // Generous drain scaled to payload before closing the socket.
                val drain = maxOf(1500L, bytes.size.toLong())
                Log.i(tag, "wrote ${bytes.size} bytes via $label, draining ${drain}ms")
                Thread.sleep(drain)
                try {
                    socket.close()
                } catch (_: Exception) {
                }
                Log.i(tag, "done via $label")
                return true
            } catch (e: Exception) {
                Log.w(tag, "$label failed: ${e.message}")
                try {
                    socket?.close()
                } catch (_: Exception) {
                }
            }
        }
        Log.w(tag, "all connectors failed")
        return false
    }
}
