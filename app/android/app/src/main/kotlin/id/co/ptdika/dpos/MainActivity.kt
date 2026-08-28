package id.co.ptdika.dpos

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Hold the Android 12+ system splash on screen for a few seconds so the
    // brand splash can actually be read (it otherwise vanishes at Flutter's
    // first frame). No Flutter-drawn splash — this only delays the first draw.
    private var splashHoldOver = false

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
