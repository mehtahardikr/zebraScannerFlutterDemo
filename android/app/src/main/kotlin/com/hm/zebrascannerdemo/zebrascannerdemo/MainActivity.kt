package com.hm.zebrascannerdemo.zebrascannerdemo


import android.app.Dialog
import android.graphics.Point
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.util.Log
import android.view.View
import android.view.Window
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.annotation.NonNull
import androidx.appcompat.widget.AppCompatButton
import androidx.appcompat.widget.AppCompatTextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.hm.zebrascannerdemo.zebrascannerdemo.adapter.ScannerDataAdapter
import com.hm.zebrascannerdemo.zebrascannerdemo.adapter.ScannerDataAdapter.RecyclerViewItemClickListener
import com.hm.zebrascannerdemo.zebrascannerdemo.models.ScannerData
import com.hm.zebrascannerdemo.zebrascannerdemo.utils.Constants
import com.hm.zebrascannerdemo.zebrascannerdemo.utils.Utils
import com.zebra.scannercontrol.*
import com.zebra.scannercontrol.DCSSDKDefs.DCSSDK_RESULT
import com.zebra.scannercontrol.RMDAttributes.RMD_ATTR_VALUE_ACTION_HIGH_HIGH_LOW_LOW_BEEP
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import java.util.concurrent.Executor
import java.util.concurrent.Executors


class MainActivity : FlutterActivity(), IDcsSdkApiDelegate {


    lateinit var mResult: MethodChannel.Result
    var sdkHandler: SDKHandler? = null
    var connectedScannerID = 0
    var mScannerInfoList: MutableList<DCSScannerInfo> = mutableListOf<DCSScannerInfo>()


    // Declare our eventSink later it will be initialized
    var eventSinkScanner: EventChannel.EventSink? = null
    var eventSinkBarcode: EventChannel.EventSink? = null

    private val TAG: String = MainActivity::class.java.name;

    var barCodeView: BarCodeView? = null
    var llBarcode: FrameLayout? = null


    override fun onStart() {
        super.onStart()
        /*with(sdkHandler) {
            if (this == null) {
                Log.e("Main sdk", "not initialised")
                initComponents()
            } else {
                Log.e("Main sdk", "already initialised")
            }
        }*/


    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                Constants.CHANNEL
        ).setMethodCallHandler { call, result ->

            print(call.method)
            mResult = result
            when (call.method) {
                Constants.EVENT_INIT -> initComponents()
                Constants.EVENT_PAIR -> openPairingDialog()
                Constants.EVENT_GET_LIST -> getAvailableList()
                Constants.EVENT_ACTIVE_SCANNER_LIST -> getActiveScannerList()
                Constants.EVENT_TEST_BEEP -> {
                    val map = call.arguments as HashMap<*, *>
                    Log.i(TAG, "map = " + map)
                    val deviceId: String? = call.argument("deviceId")
                    testBeep(deviceId!!)
                }
                Constants.EVENT_DISCONNECT -> {
                    val map = call.arguments as HashMap<*, *>
                    Log.i(TAG, "map = " + map)
                    val deviceId: String? = call.argument("deviceId")
                    disconnectDevice(deviceId!!)
                }
                else -> result.notImplemented()
            }

        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.EVENT_CHANNEL).setStreamHandler(
                object : StreamHandler {
                    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                        eventSinkScanner = sink
                    }

                    override fun onCancel(arguments: Any?) {
                        eventSinkScanner = null
                    }

                }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.EVENT_CHANNEL_BARCODE).setStreamHandler(
                object : StreamHandler {
                    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                        eventSinkBarcode = sink
                    }

                    override fun onCancel(arguments: Any?) {
                        eventSinkBarcode = null
                    }

                }
        )

    }

    /**
     *  get available list
     */
    private fun getAvailableList() {

        if(sdkHandler== null )
            return
        mScannerInfoList.clear()

        var customDialog: Dialog
        sdkHandler!!.dcssdkGetAvailableScannersList(mScannerInfoList)

        if (mScannerInfoList.isNotEmpty()) {
            customDialog = Dialog(this@MainActivity, R.style.Theme_AppCompat_Light_Dialog)

            customDialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
            customDialog.setContentView(R.layout.custom_dialog_layout)
            //customDialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            customDialog.setCancelable(false);

            val btnClose = customDialog.findViewById(R.id.btnCancel) as AppCompatButton
            val rvList = customDialog.findViewById(R.id.rvList) as RecyclerView

            val mLayoutManager: RecyclerView.LayoutManager = LinearLayoutManager(this@MainActivity)
            rvList.setLayoutManager(mLayoutManager)
            val adapter: ScannerDataAdapter = ScannerDataAdapter(mScannerInfoList,
                    object : RecyclerViewItemClickListener {
                        override fun clickOnItem(data: Int?) {
                            customDialog.dismiss()

                            sdkHandler!!.dcssdkEstablishCommunicationSession(data!!)


                        }
                    }

            )
            rvList.adapter = adapter

            customDialog.show()

            btnClose.setOnClickListener(View.OnClickListener {
                if (customDialog.isShowing) {
                    customDialog.dismiss()
                }
            })
        }
    }

    /**
     *  provide the list of scanner
     *  that is paired with app as well as
     *  connected with the app
     */
    private fun getActiveScannerList() {

        if(sdkHandler == null)
            return

        sdkHandler!!.dcssdkGetActiveScannersList(mScannerInfoList)

        var list: MutableList<ScannerData> = mutableListOf<ScannerData>()

        mScannerInfoList.forEach { e ->
            list.add(ScannerData(id = e.scannerID.toString(), name = e.scannerName, active = e.isActive, event = "N/A"))
        }

        eventSinkScanner?.success(Utils.toJsonString(list))


    }


    /**
     *  test beep
     */
    private fun testBeep(deviceId: String) {

        if(sdkHandler ==null) return

        val value: Int = RMD_ATTR_VALUE_ACTION_HIGH_HIGH_LOW_LOW_BEEP//RMD_ATTR_VALUE_ACTION_HIGH_LONG_BEEP_1
        val inXML = ("<inArgs><scannerID>" + deviceId + "</scannerID><cmdArgs><arg-int>"
                + Integer.toString(value) + "</arg-int></cmdArgs></inArgs>")

        val scannerId: Int = Integer.parseInt(deviceId)

        val scope = CoroutineScope(Dispatchers.Main)
        scope.launch {
            async(Dispatchers.IO) {
                val result: DCSSDKDefs.DCSSDK_RESULT = sdkHandler!!.dcssdkExecuteCommandOpCodeInXMLForScanner(DCSSDKDefs.DCSSDK_COMMAND_OPCODE.DCSSDK_SET_ACTION, inXML, StringBuilder())

                runOnUiThread(Runnable {
                    if (result == DCSSDKDefs.DCSSDK_RESULT.DCSSDK_RESULT_SUCCESS) {

                        val data = ScannerData(id = deviceId, event = "beeped", name = "", active = true)

                        eventSinkScanner?.success(Utils.toJsonString(data))
                    }
                    if (result == DCSSDKDefs.DCSSDK_RESULT.DCSSDK_RESULT_FAILURE) {
                        eventSinkScanner?.error("400", "Event passed failed", "command failed")
                    }
                })

            }.await()
        }
    }

    /**
     *  disconnect device
     */
    private fun disconnectDevice(deviceId: String) {

        if(sdkHandler ==null) return

        val result: DCSSDK_RESULT = sdkHandler!!.dcssdkTerminateCommunicationSession(Integer.parseInt(deviceId))


        if (result == DCSSDKDefs.DCSSDK_RESULT.DCSSDK_RESULT_SUCCESS) {

            val data = ScannerData(id = deviceId, event = "disconnected", name = "", active = true)

            eventSinkScanner?.success(Utils.toJsonString(data))

        }
        if (result == DCSSDKDefs.DCSSDK_RESULT.DCSSDK_RESULT_FAILURE) {
            eventSinkScanner?.error("400", "disconnect event failed", "command failed")
        }

    }

    /**
     *  open pairing dialog
     */
    lateinit var dialogPairNewScanner: Dialog

    private fun openPairingDialog() {

        if(sdkHandler ==null) return

        dialogPairNewScanner = Dialog(this@MainActivity, android.R.style.Theme_DeviceDefault_Light_Dialog)

        dialogPairNewScanner.requestWindowFeature(Window.FEATURE_NO_TITLE)
        dialogPairNewScanner.setContentView(R.layout.layout_dialog_barcode);
        dialogPairNewScanner.setCancelable(false);

        val cancelButton: AppCompatTextView = dialogPairNewScanner.findViewById(R.id.btn_cancel) as AppCompatTextView
        llBarcode = dialogPairNewScanner.findViewById(R.id.scan_to_connect_barcode) as FrameLayout


        barCodeView = null

        if (sdkHandler != null) {
            barCodeView = sdkHandler!!.dcssdkGetPairingBarcode(
                    DCSSDKDefs.DCSSDK_BT_PROTOCOL.SSI_BT_LE,
                    DCSSDKDefs.DCSSDK_BT_SCANNER_CONFIG.SET_FACTORY_DEFAULTS
            )


            if (barCodeView != null && llBarcode != null) {

                val layoutParams: LinearLayout.LayoutParams = LinearLayout.LayoutParams(-1, -1)
                val display = windowManager.defaultDisplay
                val size = Point()
                display.getSize(size)
                val width = size.x
                val height = size.y
                val x = width * 8 / 10
                val y = x / 3
                barCodeView?.setSize(x, y)
                llBarcode?.addView(barCodeView, layoutParams)
                dialogPairNewScanner.setCancelable(false)
                dialogPairNewScanner.setCanceledOnTouchOutside(false)
                dialogPairNewScanner.show()
                val window: Window? = dialogPairNewScanner.window
                window?.let {
                    window.setLayout(LinearLayout.LayoutParams.MATCH_PARENT, getY())
                }

            }
        }

        cancelButton.setOnClickListener(View.OnClickListener {
            if (dialogPairNewScanner.isShowing) {
                dialogPairNewScanner.dismiss()
            }
        })

    }

    private fun getY(): Int {
        val scale = this.resources.displayMetrics.density
        return (220 * scale + 0.5f).toInt()
    }

    /**
     *  init components
     */
    private fun initComponents() {

        if(sdkHandler != null ) return

        sdkHandler = SDKHandler(this@MainActivity, true)
        sdkHandler!!.dcssdkSetDelegate(this@MainActivity)
        sdkHandler!!.dcssdkSetOperationalMode(DCSSDKDefs.DCSSDK_MODE.DCSSDK_OPMODE_BT_NORMAL)
        sdkHandler!!.dcssdkSetOperationalMode(DCSSDKDefs.DCSSDK_MODE.DCSSDK_OPMODE_BT_LE)


        var notifications_mask = 0
        // We would like to subscribe to all scanner available/not-available events
        notifications_mask =
                notifications_mask or (DCSSDKDefs.DCSSDK_EVENT.DCSSDK_EVENT_SCANNER_APPEARANCE.value or
                        DCSSDKDefs.DCSSDK_EVENT.DCSSDK_EVENT_SCANNER_DISAPPEARANCE.value)
        // We would like to subscribe to all scanner connection events
        notifications_mask =
                notifications_mask or (DCSSDKDefs.DCSSDK_EVENT.DCSSDK_EVENT_SESSION_ESTABLISHMENT.value or
                        DCSSDKDefs.DCSSDK_EVENT.DCSSDK_EVENT_SESSION_TERMINATION.value)
        // We would like to subscribe to all barcode events
        notifications_mask =
                notifications_mask or DCSSDKDefs.DCSSDK_EVENT.DCSSDK_EVENT_BARCODE.value


        // subscribe to events set in notification mask
        sdkHandler!!.dcssdkSubsribeForEvents(notifications_mask)


    }

    override fun dcssdkEventScannerAppeared(p0: DCSScannerInfo?) {
        if (this::dialogPairNewScanner.isInitialized) {
            if (dialogPairNewScanner.isShowing) {
                dialogPairNewScanner.dismiss()
            }
        }

        val data = ScannerData(id = p0!!.scannerID.toString(), event = "appeared", name = p0.scannerName, active = p0.isActive)

        eventSinkScanner?.success(Utils.toJsonString(data))
        mScannerInfoList.clear()
        mScannerInfoList.add(p0)
    }

    override fun dcssdkEventScannerDisappeared(p0: Int) {

        eventSinkScanner?.error("400", "device disappeared", p0.toString())
    }

    override fun dcssdkEventCommunicationSessionEstablished(p0: DCSScannerInfo?) {
        connectedScannerID = p0!!.getScannerID();

        val data = ScannerData(id = p0.scannerID.toString(), event = "connected", name = p0.scannerName, active = p0.isActive)

        eventSinkScanner?.success(Utils.toJsonString(data))


    }

    override fun dcssdkEventCommunicationSessionTerminated(p0: Int) {
        runOnUiThread {
            eventSinkScanner?.error("400", "device communication lost trying to reconnect", p0.toString())

        }
    }

    override fun dcssdkEventBarcode(barcodeData: ByteArray?, barcodeType: Int, fromScannerID: Int) {
        val code = String(barcodeData!!)
        dataHandler.obtainMessage(Constants.BARCODE_RECEIVED, code).sendToTarget();
    }

    override fun dcssdkEventImage(p0: ByteArray?, p1: Int) {

    }

    override fun dcssdkEventVideo(p0: ByteArray?, p1: Int) {

    }

    override fun dcssdkEventBinaryData(p0: ByteArray?, p1: Int) {

    }

    override fun dcssdkEventFirmwareUpdate(p0: FirmwareUpdateEvent?) {

    }

    override fun dcssdkEventAuxScannerAppeared(p0: DCSScannerInfo?, p1: DCSScannerInfo?) {

    }

    private val dataHandler: Handler = object : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                Constants.BARCODE_RECEIVED -> {
                    val code = msg.obj as String
                    eventSinkBarcode?.success(code)
                }
            }
        }
    }


}
