package id.co.ptdika.dpos

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothProfile
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
                } else if (call.method == "printBytesRongtaBle") {
                    // SEPARATE BLE/GATT path for the RP58_BU (does not touch anything above).
                    val mac = call.argument<String>("mac")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (mac == null || bytes == null) {
                        result.success("FAIL(BLE): null args")
                    } else {
                        Thread {
                            val status = printBytesRongtaBle(mac, bytes)
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

    private fun shortUuid(u: String): String = if (u.length >= 8) u.substring(4, 8) else u

    // SEPARATE BLE/GATT path for the Rongta RP58_BU (does NOT touch printBytes /
    // printBytesRongta). Classic SPP connects+writes but never prints on this unit,
    // which is iOS-compatible => its print engine is on BLE. Connect over LE, discover
    // services, write the ESC/POS bytes to the first writable characteristic in 20-byte
    // chunks, and report which service/characteristic was used (or dump the services
    // when none is writable). Blocks on a latch for the async GATT callbacks.
    private fun printBytesRongtaBle(mac: String, bytes: ByteArray): String {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return "FAIL(BLE): no BT adapter"
        val device: BluetoothDevice = try {
            adapter.getRemoteDevice(mac)
        } catch (e: Exception) {
            return "FAIL(BLE): bad mac ($mac)"
        }
        val latch = java.util.concurrent.CountDownLatch(1)
        val done = java.util.concurrent.atomic.AtomicReference<String?>(null)
        val chunks = java.util.concurrent.ConcurrentLinkedQueue<ByteArray>()
        var off = 0
        while (off < bytes.size) {
            val end = minOf(off + 20, bytes.size)
            chunks.add(bytes.copyOfRange(off, end))
            off = end
        }
        val totalChunks = chunks.size

        val cb = object : BluetoothGattCallback() {
            var target: BluetoothGattCharacteristic? = null
            var usedChar = ""

            fun finish(msg: String) {
                if (done.compareAndSet(null, msg)) latch.countDown()
            }

            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    g.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    finish("FAIL(BLE): disconnected status=$status")
                }
            }

            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                val writables = ArrayList<BluetoothGattCharacteristic>()
                for (svc in g.services) {
                    for (ch in svc.characteristics) {
                        val p = ch.properties
                        if (p and (BluetoothGattCharacteristic.PROPERTY_WRITE or
                                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0) {
                            writables.add(ch)
                        }
                    }
                }
                if (writables.isEmpty()) {
                    val svcs = g.services.joinToString(",") { shortUuid(it.uuid.toString()) }
                    finish("FAIL(BLE): no writable char. services=[$svcs]")
                    return
                }
                target = writables[0]
                usedChar = shortUuid(target!!.uuid.toString())
                writeNext(g)
            }

            fun writeNext(g: BluetoothGatt) {
                val chunk = chunks.poll()
                val ch = target
                if (chunk == null || ch == null) {
                    finish("BLE OK: wrote ${bytes.size}B to char=$usedChar ($totalChunks chunks)")
                    return
                }
                ch.value = chunk
                ch.writeType =
                    if (ch.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0)
                        BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                    else BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                if (!g.writeCharacteristic(ch)) {
                    finish("FAIL(BLE): writeCharacteristic rejected (char=$usedChar)")
                }
            }

            override fun onCharacteristicWrite(
                g: BluetoothGatt,
                ch: BluetoothGattCharacteristic,
                status: Int,
            ) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    finish("FAIL(BLE): write status=$status (char=$usedChar)")
                    return
                }
                try {
                    Thread.sleep(15)
                } catch (_: Exception) {
                }
                writeNext(g)
            }
        }

        val gatt: BluetoothGatt? = try {
            device.connectGatt(this, false, cb, BluetoothDevice.TRANSPORT_LE)
        } catch (e: Exception) {
            return "FAIL(BLE): connectGatt threw ${e.message}"
        }
        try {
            latch.await(20, java.util.concurrent.TimeUnit.SECONDS)
        } catch (_: Exception) {
        }
        try {
            Thread.sleep(500) // let a trailing no-response write flush to paper
        } catch (_: Exception) {
        }
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {
        }
        return done.get() ?: "FAIL(BLE): timeout (no connect/discover)"
    }
}
