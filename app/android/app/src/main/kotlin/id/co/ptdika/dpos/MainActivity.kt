package id.co.ptdika.dpos

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    // Hold the Android 12+ system splash on screen for a few seconds so the
    // brand splash can actually be read (it otherwise vanishes at Flutter's
    // first frame). No Flutter-drawn splash — this only delays the first draw.
    private var splashHoldOver = false

    private val spp: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    // Native ESC/POS bytes over classic Bluetooth SPP. Tries an INSECURE RFCOMM
    // socket first (cheap thermal printers like RPP02N reject the secure one that
    // the print_bluetooth_thermal plugin uses), then secure, then the reflection
    // channel-1 fallback.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dpos/printer")
            .setMethodCallHandler { call, result ->
                if (call.method == "printBytes") {
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val content = findViewById<View>(android.R.id.content)
            content.viewTreeObserver.addOnPreDrawListener(
                object : ViewTreeObserver.OnPreDrawListener {
                    override fun onPreDraw(): Boolean {
                        if (splashHoldOver) {
                            content.viewTreeObserver.removeOnPreDrawListener(this)
                            return true
                        }
                        return false
                    }
                },
            )
            Handler(Looper.getMainLooper()).postDelayed({ splashHoldOver = true }, 3000)
        }
    }
}
