package dev.nanaloveyuki.madk.fixture

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbAccessory
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import android.view.WindowInsets
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.nio.charset.StandardCharsets
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

class MainActivity : Activity() {
  private lateinit var usbManager: UsbManager
  private lateinit var statusView: TextView
  private lateinit var statsView: TextView
  private lateinit var ioExecutor: ExecutorService
  private var descriptor: ParcelFileDescriptor? = null
  @Volatile private var output: DataOutputStream? = null
  @Volatile private var connectedAccessory: UsbAccessory? = null
  @Volatile private var permissionGranted = false
  private val rxBytes = AtomicLong(0)
  private val txBytes = AtomicLong(0)
  private val rxFrames = AtomicLong(0)
  private val txFrames = AtomicLong(0)

  private val permissionReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      if (intent.action != ACTION_USB_PERMISSION) return
      val accessory = accessoryFrom(intent) ?: return
      permissionGranted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
      Log.i(TAG, "USB accessory permission granted=$permissionGranted")
      if (permissionGranted) {
        openAccessory(accessory)
      } else {
        Log.w(TAG, "USB accessory permission denied")
        setStatus("Permission denied for accessory")
      }
    }
  }

  private val accessoryReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      when (intent.action) {
        UsbManager.ACTION_USB_ACCESSORY_ATTACHED -> {
          Log.i(TAG, "USB accessory attached")
          accessoryFrom(intent)?.let { requestPermission(it) }
        }
        UsbManager.ACTION_USB_ACCESSORY_DETACHED -> {
          Log.i(TAG, "USB accessory detached")
          val detached = accessoryFrom(intent)
          if (detached == null || detached == connectedAccessory) {
            closeAccessory("Accessory detached")
          }
        }
      }
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    Log.i(TAG, "Activity created")
    usbManager = getSystemService(USB_SERVICE) as UsbManager
    ioExecutor = Executors.newSingleThreadExecutor()
    setContentView(createContent())
    registerReceivers()
    handleIntent(intent)
    refreshStatus()
  }

  private fun createContent(): ScrollView {
    val content = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(dp(16), dp(16), dp(16), dp(16))
    }
    val title = TextView(this).apply {
      text = "madk Android Open Accessory fixture"
      textSize = 20f
    }
    statusView = TextView(this).apply {
      textSize = 16f
      setPadding(0, dp(24), 0, dp(12))
    }
    statsView = TextView(this).apply {
      setPadding(0, 0, 0, dp(20))
    }
    val statusButton = Button(this).apply {
      text = "Send status frame"
      setOnClickListener { sendFrame("status") }
    }
    val echoButton = Button(this).apply {
      text = "Send echo frame"
      setOnClickListener { sendFrame("echo-from-android") }
    }
    val note = TextView(this).apply {
      text = "This app does not perform AOA handshake. The accessory host must " +
        "negotiate AOA and start accessory mode first."
      setPadding(0, dp(20), 0, 0)
    }
    content.addView(title, matchParent())
    content.addView(statusView, matchParent())
    content.addView(statsView, matchParent())
    content.addView(statusButton, matchParent())
    content.addView(echoButton, matchParent())
    content.addView(note, matchParent())
    return ScrollView(this).apply {
      setOnApplyWindowInsetsListener { view, insets ->
        if (Build.VERSION.SDK_INT >= 30) {
          val bars = insets.getInsets(WindowInsets.Type.systemBars())
          view.setPadding(view.paddingLeft, bars.top, view.paddingRight, bars.bottom)
        } else {
          @Suppress("DEPRECATION")
          view.setPadding(
            view.paddingLeft,
            insets.systemWindowInsetTop,
            view.paddingRight,
            insets.systemWindowInsetBottom,
          )
        }
        insets
      }
      addView(content)
    }
  }

  private fun dp(value: Int): Int =
    (value * resources.displayMetrics.density).toInt()

  private fun matchParent(): ViewGroup.LayoutParams = ViewGroup.LayoutParams(
    ViewGroup.LayoutParams.MATCH_PARENT,
    ViewGroup.LayoutParams.WRAP_CONTENT,
  )

  private fun registerReceivers() {
    val permissionFilter = IntentFilter(ACTION_USB_PERMISSION)
    val accessoryFilter = IntentFilter().apply {
      addAction(UsbManager.ACTION_USB_ACCESSORY_ATTACHED)
      addAction(UsbManager.ACTION_USB_ACCESSORY_DETACHED)
    }
    if (Build.VERSION.SDK_INT >= 33) {
      registerReceiver(permissionReceiver, permissionFilter, RECEIVER_NOT_EXPORTED)
      registerReceiver(accessoryReceiver, accessoryFilter, RECEIVER_NOT_EXPORTED)
    } else {
      @Suppress("DEPRECATION")
      registerReceiver(permissionReceiver, permissionFilter)
      @Suppress("DEPRECATION")
      registerReceiver(accessoryReceiver, accessoryFilter)
    }
  }

  private fun handleIntent(intent: Intent?) {
    if (intent?.action == UsbManager.ACTION_USB_ACCESSORY_ATTACHED) {
      Log.i(TAG, "Handling accessory attach intent")
      accessoryFrom(intent)?.let { requestPermission(it) }
    }
  }

  private fun requestPermission(accessory: UsbAccessory) {
    Log.i(TAG, "Requesting USB accessory permission")
    if (usbManager.hasPermission(accessory)) {
      permissionGranted = true
      Log.i(TAG, "USB accessory permission already granted")
      openAccessory(accessory)
      return
    }
    permissionGranted = false
    val permissionIntent = PendingIntent.getBroadcast(
      this,
      0,
      Intent(ACTION_USB_PERMISSION).setPackage(packageName),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    Log.i(TAG, "USB accessory permission request sent")
    usbManager.requestPermission(accessory, permissionIntent)
    setStatus("Waiting for USB accessory permission")
  }

  private fun openAccessory(accessory: UsbAccessory) {
    Log.i(TAG, "Opening USB accessory")
    closeAccessory("Opening accessory")
    val opened = usbManager.openAccessory(accessory)
    if (opened == null) {
      Log.e(TAG, "UsbManager.openAccessory returned null")
      setStatus("UsbManager.openAccessory returned null")
      return
    }
    descriptor = opened
    connectedAccessory = accessory
    Log.i(TAG, "USB accessory opened; starting frame reader")
    setStatus("Connected; AOA protocol is host-negotiated")
    ioExecutor.execute { readFrames(opened) }
  }

  private fun readFrames(opened: ParcelFileDescriptor) {
    var input: DataInputStream? = null
    var streamOutput: DataOutputStream? = null
    try {
      // Keep the Activity-owned descriptor open while each direction owns a
      // duplicated descriptor. Closing one stream must not close the other.
      val inputDescriptor = ParcelFileDescriptor.dup(opened.fileDescriptor)
      val outputDescriptor = ParcelFileDescriptor.dup(opened.fileDescriptor)
      val inputStream = DataInputStream(
        BufferedInputStream(ParcelFileDescriptor.AutoCloseInputStream(inputDescriptor)),
      )
      input = inputStream
      val outputStream = DataOutputStream(
        BufferedOutputStream(ParcelFileDescriptor.AutoCloseOutputStream(outputDescriptor)),
      )
      streamOutput = outputStream
      output = outputStream
      Log.i(TAG, "Accessory frame stream opened")
      while (!Thread.currentThread().isInterrupted) {
        val length = inputStream.readInt()
        if (length <= 0 || length > MAX_FRAME_BYTES) {
          throw IllegalArgumentException("invalid frame length: $length")
        }
        val body = ByteArray(length)
        inputStream.readFully(body)
        rxBytes.addAndGet(length.toLong() + 4)
        rxFrames.incrementAndGet()
        val text = String(body, StandardCharsets.UTF_8)
        Log.d(TAG, "Received frame length=$length text=$text")
        val response = if (text == "status") {
          "status:connected;protocol=host-negotiated"
        } else {
          "echo:" + text
        }
        writeFrame(outputStream, response.toByteArray(StandardCharsets.UTF_8))
        refreshStatus()
      }
    } catch (_: EOFException) {
      Log.i(TAG, "Accessory stream closed")
      setStatus("Accessory stream closed")
    } catch (error: Exception) {
      Log.e(TAG, "Accessory I/O stopped", error)
      setStatus("Accessory I/O stopped: ${error.message ?: error.javaClass.simpleName}")
    } finally {
      output = null
      try {
        streamOutput?.close()
      } catch (_: Exception) {
      }
      try {
        input?.close()
      } catch (_: Exception) {
      }
      runOnUiThread {
        if (descriptor?.fileDescriptor == opened.fileDescriptor) {
          descriptor = null
          connectedAccessory = null
          refreshStatus()
        }
      }
    }
  }

  private fun sendFrame(text: String) {
    val bytes = text.toByteArray(StandardCharsets.UTF_8)
    val stream = output
    if (stream == null) {
      Log.w(TAG, "Cannot send frame while accessory is disconnected")
      setStatus("Not connected to an Android accessory")
      return
    }
    ioExecutor.execute {
      try {
        writeFrame(stream, bytes)
        setStatus("Sent $text frame")
      } catch (error: Exception) {
        Log.e(TAG, "Accessory frame write failed", error)
        setStatus("Write failed: ${error.message ?: error.javaClass.simpleName}")
      }
    }
  }

  private fun writeFrame(stream: DataOutputStream, body: ByteArray) {
    synchronized(stream) {
      stream.writeInt(body.size)
      stream.write(body)
      stream.flush()
    }
    txBytes.addAndGet(body.size.toLong() + 4)
    txFrames.incrementAndGet()
    Log.d(TAG, "Sent frame length=" + body.size)
  }

  private fun closeAccessory(reason: String) {
    Log.i(TAG, "Closing accessory: $reason")
    output = null
    connectedAccessory = null
    try {
      descriptor?.close()
    } catch (_: Exception) {
    }
    descriptor = null
    setStatus(reason)
  }

  private fun setStatus(message: String) {
    runOnUiThread {
      if (::statusView.isInitialized) statusView.text = message
      refreshStatus()
    }
  }

  private fun refreshStatus() {
    if (!::statsView.isInitialized) return
    val update = {
      val connected = descriptor != null
      statsView.text = "Connection: ${if (connected) "connected" else "disconnected"}\n" +
        "Permission: ${if (permissionGranted) "granted" else "not granted"}\n" +
        "AOA protocol: host-negotiated (not exposed by UsbManager)\n" +
        "RX: ${rxBytes.get()} bytes / ${rxFrames.get()} frames\n" +
        "TX: ${txBytes.get()} bytes / ${txFrames.get()} frames"
    }
    if (Looper.myLooper() == Looper.getMainLooper()) {
      update()
    } else {
      runOnUiThread(update)
    }
  }

  private fun accessoryFrom(intent: Intent): UsbAccessory? {
    return if (Build.VERSION.SDK_INT >= 33) {
      intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY, UsbAccessory::class.java)
    } else {
      @Suppress("DEPRECATION")
      intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY)
    }
  }

  override fun onStart() {
    super.onStart()
    Log.i(TAG, "Activity started")
  }

  override fun onStop() {
    Log.i(TAG, "Activity stopped")
    super.onStop()
  }

  override fun onDestroy() {
    Log.i(TAG, "Activity destroyed")
    closeAccessory("Activity destroyed")
    ioExecutor.shutdownNow()
    unregisterReceiver(permissionReceiver)
    unregisterReceiver(accessoryReceiver)
    super.onDestroy()
  }

  companion object {
    private const val TAG = "madk-fixture"
    private const val ACTION_USB_PERMISSION = "dev.nanaloveyuki.madk.fixture.USB_PERMISSION"
    private const val MAX_FRAME_BYTES = 64 * 1024
  }
}
