package id.co.ptdika.dpos

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
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
                    // Returns a human-readable status string (HyperOS suppresses app
                    // logcat on release builds, so diagnostics are surfaced in the UI).
                    val mac = call.argument<String>("mac")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (mac == null || bytes == null) {
                        result.success("FAIL: null args")
                    } else {
                        Thread {
                            val status = printBytesRongta(mac, bytes)
                            Handler(Looper.getMainLooper()).post { result.success(status) }
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
    // Returns a human-readable status string surfaced in the app toast (HyperOS
    // suppresses app logcat on release builds). SDP-resolved sockets ONLY (secure
    // first, then insecure) — never the channel-1 reflection hack; chunked write;
    // generous drain before close.
    private fun printBytesRongta(mac: String, bytes: ByteArray): String {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return "FAIL: no BT adapter"
        val device: BluetoothDevice = try {
            adapter.getRemoteDevice(mac)
        } catch (e: Exception) {
            return "FAIL: bad mac ($mac)"
        }
        val info = "dev=${device.name} bond=${device.bondState} n=${bytes.size}"
        try {
            adapter.cancelDiscovery()
        } catch (_: Exception) {
        }

        val makers: List<Pair<String, () -> BluetoothSocket?>> = listOf(
            "secure-sdp" to { device.createRfcommSocketToServiceRecord(spp) },
            "insecure-sdp" to { device.createInsecureRfcommSocketToServiceRecord(spp) },
        )

        val errs = StringBuilder()
        for ((label, make) in makers) {
            var socket: BluetoothSocket? = null
            try {
                socket = make() ?: continue
                socket.connect()
                val out = socket.outputStream
                var off = 0
                val chunk = 256
                while (off < bytes.size) {
                    val end = minOf(off + chunk, bytes.size)
                    out.write(bytes, off, end - off)
                    out.flush()
                    off = end
                    Thread.sleep(20)
                }
                val drain = maxOf(1500L, bytes.size.toLong())
                Thread.sleep(drain)
                try {
                    socket.close()
                } catch (_: Exception) {
                }
                return "OK via $label | $info drain=${drain}ms"
            } catch (e: Exception) {
                errs.append("$label:${e.message}; ")
                try {
                    socket?.close()
                } catch (_: Exception) {
                }
            }
        }
        return "FAIL: $info | $errs"
    }
}
