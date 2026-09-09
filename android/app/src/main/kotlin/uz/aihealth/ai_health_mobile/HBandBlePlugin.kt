package uz.aihealth.ai_health_mobile

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.content.ContextCompat.startForegroundService
import com.inuker.bluetooth.library.Code
import com.inuker.bluetooth.library.Constants
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IABleConnectStatusListener
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.IBatteryDataListener
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IHeartDataListener
import com.veepoo.protocol.listener.data.IOriginData3Listener
import com.veepoo.protocol.listener.data.IPersonInfoDataListener
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISleepDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.listener.data.ISportDataListener
import com.veepoo.protocol.model.datas.BatteryData
import com.veepoo.protocol.model.datas.DeviceFunctionPackage1
import com.veepoo.protocol.model.datas.DeviceFunctionPackage2
import com.veepoo.protocol.model.datas.DeviceFunctionPackage3
import com.veepoo.protocol.model.datas.DeviceFunctionPackage4
import com.veepoo.protocol.model.datas.DeviceFunctionPackage5
import com.veepoo.protocol.model.datas.FunctionDeviceSupportData
import com.veepoo.protocol.model.datas.FunctionSocailMsgData
import com.veepoo.protocol.model.datas.HRVOriginData
import com.veepoo.protocol.model.datas.HalfHourRateData
import com.veepoo.protocol.model.datas.HalfHourSportData
import com.veepoo.protocol.model.datas.HeartData
import com.veepoo.protocol.model.datas.OriginData3
import com.veepoo.protocol.model.datas.OriginHalfHourData
import com.veepoo.protocol.model.datas.PersonInfoData
import com.veepoo.protocol.model.datas.PwdData
import com.veepoo.protocol.model.datas.SleepData
import com.veepoo.protocol.model.datas.SleepPrecisionData
import com.veepoo.protocol.model.datas.Spo2hOriginData
import com.veepoo.protocol.model.datas.TimeData
import com.veepoo.protocol.model.enums.EHeartStatus
import com.veepoo.protocol.model.enums.EPwdStatus
import com.veepoo.protocol.model.enums.ESex
import com.veepoo.protocol.model.settings.CustomSettingData
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import no.nordicsemi.android.support.v18.scanner.BluetoothLeScannerCompat
import no.nordicsemi.android.support.v18.scanner.ScanCallback
import no.nordicsemi.android.support.v18.scanner.ScanResult
import no.nordicsemi.android.support.v18.scanner.ScanSettings
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.Calendar
import java.util.concurrent.atomic.AtomicBoolean

class HBandBlePlugin(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scanner = BluetoothLeScannerCompat.getScanner()
    private var scanSink: EventChannel.EventSink? = null
    private var connectionSink: EventChannel.EventSink? = null
    private var healthSink: EventChannel.EventSink? = null
    private var scanning = false
    private var selectedAddress: String? = null
    private var selectedName: String? = null
    private var firmware: String? = null
    private var modelName: String? = null
    private var batteryLevel: Int? = null
    private var watchDataDay = 3
    private var pendingConnectResult: MethodChannel.Result? = null
    private var connectTimeout: Runnable? = null
    private var liveStepRunnable: Runnable? = null
    private var sdkReady = false

    private val writeResponse = IBleWriteResponse { code ->
        Log.d(TAG, "BLE write response=$code")
    }

    private val connectStatusListener = object : IABleConnectStatusListener() {
        override fun onConnectStatusChanged(mac: String?, status: Int) {
            Log.i(TAG, "connect status mac=$mac status=$status")
            if (status == Constants.STATUS_DISCONNECTED) {
                emitConnection("disconnected")
            }
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            emitScanResult(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach(::emitScanResult)
        }

        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "Scan failed code=$errorCode")
            mainHandler.post {
                scanning = false
                scanSink?.error("BLE_SCAN_FAILED", "BLE scan failed with code $errorCode", null)
                if (selectedAddress == null) emitConnection("disconnected")
            }
        }
    }

    fun register() {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, SCAN_CHANNEL).setStreamHandler(simpleHandler { scanSink = it })
        EventChannel(messenger, CONNECTION_CHANNEL).setStreamHandler(simpleHandler { connectionSink = it })
        EventChannel(messenger, HEALTH_CHANNEL).setStreamHandler(simpleHandler { healthSink = it })
        initSdk()
    }

    fun dispose() {
        stopBleScan()
        stopLiveMetrics()
        if (selectedAddress != null) {
            runCatching { VPOperateManager.getInstance().disconnectWatch(writeResponse) }
        }
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "bleStatus" -> result.success(bleStatus())
            "isBluetoothOn" -> result.success(isBluetoothEnabled())
            "startScan" -> startBleScan(result)
            "stopScan" -> {
                stopBleScan()
                result.success(null)
            }
            "connect" -> connectDevice(call, result)
            "disconnect" -> disconnectDevice(result)
            "connectedDeviceInfo" -> result.success(currentDeviceMap())
            "readBatteryLevel" -> readBattery(result)
            "syncHealthHistory" -> syncHealthHistory(result)
            else -> result.notImplemented()
        }
    }

    private fun initSdk() {
        if (sdkReady) return
        val context = activity.applicationContext
        VPOperateManager.getInstance().init(context)
        VPOperateManager.getInstance().setAutoConnectBTBySdk(false)
        runCatching { VPOperateManager.getInstance().setDeviceShowConfirm(false) }
        sdkReady = true
        Log.i(TAG, "VPOperateManager initialized")
    }

    private fun bleStatus(): Map<String, Any?> = mapOf(
        "bluetoothOn" to isBluetoothEnabled(),
        "locationOn" to isLocationEnabled(),
        "androidSdk" to Build.VERSION.SDK_INT,
        "hasScanPermission" to hasScanPermission(),
        "hasConnectPermission" to hasConnectPermission(),
    )

    private fun startBleScan(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                if (!hasScanPermission()) {
                    result.error("BLE_SCAN_PERMISSION", "Bluetooth scan permission is not granted.", null)
                    return@post
                }
                if (!isBluetoothEnabled()) {
                    requestEnableBluetooth()
                    result.error("BLE_OFF", "Bluetooth is turned off.", null)
                    return@post
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && !isLocationEnabled()) {
                    result.error("LOCATION_OFF", "Location services must be enabled to scan for BLE devices.", null)
                    return@post
                }

                stopBleScan()
                val settings = ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .setLegacy(false)
                    .setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
                    .setReportDelay(0)
                    .setUseHardwareBatchingIfSupported(false)
                    .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
                    .build()
                scanner.startScan(null, settings, scanCallback)
                scanning = true
                emitConnection("scanning")
                Log.i(TAG, "BLE scan started (legacy=false, PHY_ALL)")
                result.success(null)
            } catch (error: SecurityException) {
                result.error("BLE_SCAN_PERMISSION", error.message, null)
            } catch (error: Throwable) {
                result.error("HBAND_OPERATION_FAILED", error.message, null)
            }
        }
    }

    private fun stopBleScan() {
        if (!scanning) return
        runCatching { scanner.stopScan(scanCallback) }
        scanning = false
        if (selectedAddress == null) {
            emitConnection("disconnected")
        }
        Log.i(TAG, "BLE scan stopped")
    }

    private fun emitScanResult(result: ScanResult) {
        val device = result.device
        val advertisedName = result.scanRecord?.deviceName
        val bondedName = if (hasConnectPermission()) {
            runCatching { device.name }.getOrNull()
        } else {
            null
        }
        val deviceName = advertisedName?.takeIf { it.isNotBlank() }
            ?: bondedName?.takeIf { it.isNotBlank() }
            ?: "Unknown BLE wearable"
        val address = device.address ?: return
        val uuids = result.scanRecord?.serviceUuids?.joinToString(",") { it.toString() } ?: ""
        Log.d(TAG, "scan name=$deviceName mac=$address rssi=${result.rssi} uuids=$uuids")
        mainHandler.post {
            scanSink?.success(
                mapOf(
                    "id" to address,
                    "name" to deviceName,
                    "macAddress" to address,
                    "rssi" to result.rssi,
                ),
            )
        }
    }

    private fun connectDevice(call: MethodCall, result: MethodChannel.Result) {
        val device = call.argument<Map<String, Any?>>("device")
        val password = call.argument<String>("password") ?: "0000"
        val address = device?.get("macAddress") as? String ?: device?.get("id") as? String
        val name = device?.get("name") as? String ?: "HBand"
        if (address.isNullOrBlank()) {
            result.error("BLE_CONNECT_FAILED", "Device address is missing.", null)
            return
        }
        if (!hasConnectPermission()) {
            result.error("BLE_CONNECT_PERMISSION", "Bluetooth connect permission is not granted.", null)
            return
        }
        if (!isBluetoothEnabled()) {
            result.error("BLE_OFF", "Bluetooth is turned off.", null)
            return
        }

        mainHandler.post {
            stopBleScan()
            failPendingConnect("Connection replaced by a new request.")
            pendingConnectResult = result
            selectedAddress = address
            selectedName = name
            firmware = null
            modelName = name
            batteryLevel = null
            emitConnection("connecting")

            initSdk()
            VPOperateManager.getInstance().registerConnectStatusListener(address, connectStatusListener)
            Log.i(TAG, "Connecting to $name ($address)")
            VPOperateManager.getInstance().connectDevice(
                address,
                name,
                IConnectResponse { code, _, isOadModel ->
                    Log.i(TAG, "connectDevice code=$code oad=$isOadModel")
                    if (code != Code.REQUEST_SUCCESS) {
                        failConnect(
                            "BLE_CONNECT_FAILED",
                            "Could not connect. This device may not support the Veepoo/VALDUS protocol.",
                        )
                    }
                },
                INotifyResponse { state ->
                    Log.i(TAG, "notifyState=$state")
                    if (state == Code.REQUEST_SUCCESS) {
                        confirmPassword(password)
                    } else {
                        failConnect(
                            "BLE_CONNECT_FAILED",
                            "This device does not support the Veepoo/VALDUS protocol.",
                        )
                    }
                },
            )

            connectTimeout = Runnable {
                failConnect("BLE_CONNECT_TIMEOUT", "Connection timed out. Put the band in pairing mode and try again.")
            }
            mainHandler.postDelayed(connectTimeout!!, CONNECT_TIMEOUT_MS)
        }
    }

    private fun confirmPassword(password: String) {
        VPOperateManager.getInstance().confirmDevicePwd(
            writeResponse,
            object : IPwdDataListener {
                override fun onPwdDataChange(pwdData: PwdData?) {
                    val status = pwdData?.getmStatus()
                    Log.i(TAG, "pwd status=$status data=$pwdData")
                    if (status == EPwdStatus.CHECK_FAIL) {
                        failConnect("BLE_PASSWORD", "Device password is incorrect.")
                        return
                    }
                    if (status == EPwdStatus.CHECK_SUCCESS || status == EPwdStatus.CHECK_AND_TIME_SUCCESS) {
                        firmware = pwdData.getDeviceVersion()
                        modelName = selectedName
                    }
                }

                override fun onConnectionConfirmTimeout() {
                    failConnect("BLE_CONNECT_TIMEOUT", "The band did not confirm the connection in time. Press the pairing button and retry.")
                }
            },
            object : IDeviceFuctionDataListener {
                override fun onFunctionSupportDataChange(functionSupport: FunctionDeviceSupportData?) {
                    val days = functionSupport?.wathcDay ?: 0
                    if (days > 0) watchDataDay = days
                    Log.i(TAG, "function support watchDataDay=$watchDataDay")
                }

                override fun onDeviceFunctionPackage1Report(p0: DeviceFunctionPackage1?) {}
                override fun onDeviceFunctionPackage2Report(p0: DeviceFunctionPackage2?) {}
                override fun onDeviceFunctionPackage3Report(p0: DeviceFunctionPackage3?) {}
                override fun onDeviceFunctionPackage4Report(p0: DeviceFunctionPackage4?) {}
                override fun onDeviceFunctionPackage5Report(p0: DeviceFunctionPackage5?) {}
            },
            object : ISocialMsgDataListener {
                override fun onSocialMsgSupportDataChange(p0: FunctionSocailMsgData?) {}
                override fun onSocialMsgSupportDataChange2(p0: FunctionSocailMsgData?) {}
            },
            object : ICustomSettingDataListener {
                override fun OnSettingDataChange(p0: CustomSettingData?) {
                    syncPersonInfo()
                }
            },
            password,
            true,
        )
    }

    private fun syncPersonInfo() {
        val person = PersonInfoData(ESex.MAN, 175, 70, 30, 8000)
        VPOperateManager.getInstance().syncPersonInfo(
            writeResponse,
            IPersonInfoDataListener {
                Log.i(TAG, "person info synced: $it")
                VPOperateManager.getInstance().readBattery(
                    writeResponse,
                    IBatteryDataListener { battery ->
                        batteryLevel = batteryPercent(battery)
                        completeConnect()
                    },
                )
            },
            person,
        )
        mainHandler.postDelayed({
            if (pendingConnectResult != null) {
                completeConnect()
            }
        }, 4000)
    }

    private fun startLiveHeart() {
        VPOperateManager.getInstance().startDetectHeart(
            writeResponse,
            IHeartDataListener { heart -> emitHealth(heartRate = heartBpm(heart)) },
        )
    }

    private fun startLiveMetrics() {
        startLiveHeart()
        stopLiveSteps()
        val runnable = object : Runnable {
            override fun run() {
                if (selectedAddress == null) return
                VPOperateManager.getInstance().readSportStep(
                    writeResponse,
                    ISportDataListener { sport ->
                        Log.i(TAG, "live steps=${sport.step}")
                        emitHealth(steps = sport.step)
                    },
                )
                mainHandler.postDelayed(this, LIVE_STEP_INTERVAL_MS)
            }
        }
        liveStepRunnable = runnable
        mainHandler.postDelayed(runnable, 5_000)
    }

    private fun stopLiveSteps() {
        liveStepRunnable?.let { mainHandler.removeCallbacks(it) }
        liveStepRunnable = null
    }

    private fun stopLiveMetrics() {
        stopLiveSteps()
        runCatching { VPOperateManager.getInstance().stopDetectHeart(writeResponse) }
    }

    private fun completeConnect() {
        val pending = pendingConnectResult ?: return
        clearConnectTimeout()
        pendingConnectResult = null
        emitConnection("connected")
        startCollectionService()
        pending.success(currentDeviceMap())
        Log.i(TAG, "Connect completed for $selectedAddress")
    }

    private fun failConnect(code: String, message: String) {
        val pending = pendingConnectResult ?: return
        clearConnectTimeout()
        pendingConnectResult = null
        selectedAddress?.let {
            runCatching { VPOperateManager.getInstance().disconnectWatch(writeResponse) }
            runCatching { VPOperateManager.getInstance().unregisterConnectStatusListener(it, connectStatusListener) }
        }
        selectedAddress = null
        selectedName = null
        emitConnection("disconnected")
        pending.error(code, message, null)
    }

    private fun failPendingConnect(message: String) {
        val pending = pendingConnectResult ?: return
        pendingConnectResult = null
        clearConnectTimeout()
        pending.error("BLE_CONNECT_FAILED", message, null)
    }

    private fun disconnectDevice(result: MethodChannel.Result) {
        mainHandler.post {
            stopLiveMetrics()
            selectedAddress?.let {
                runCatching { VPOperateManager.getInstance().disconnectWatch(writeResponse) }
                runCatching { VPOperateManager.getInstance().unregisterConnectStatusListener(it, connectStatusListener) }
            }
            selectedAddress = null
            selectedName = null
            firmware = null
            batteryLevel = null
            stopCollectionService()
            emitConnection("disconnected")
            result.success(null)
        }
    }

    private fun startCollectionService() {
        val context = activity.applicationContext
        val intent = Intent(context, B::class.java).apply {
            putExtra(B.EXTRA_DEVICE_NAME, selectedName ?: "smart band")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(context, intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopCollectionService() {
        val context = activity.applicationContext
        context.stopService(Intent(context, B::class.java))
    }

    private fun readBattery(result: MethodChannel.Result) {
        if (selectedAddress == null) {
            result.success(null)
            return
        }
        val reply = once(result)
        VPOperateManager.getInstance().readBattery(
            writeResponse,
            IBatteryDataListener { battery ->
                batteryLevel = batteryPercent(battery)
                emitHealth(battery = batteryLevel)
                reply.success(batteryLevel)
            },
        )
        mainHandler.postDelayed({ reply.success(batteryLevel) }, 4000)
    }

    private fun syncHealthHistory(result: MethodChannel.Result) {
        if (selectedAddress == null) {
            result.error("BLE_NOT_CONNECTED", "No device is connected.", null)
            return
        }
        val reply = once(result)
        val heartRate = mutableListOf<Map<String, Any?>>()
        val spo2 = mutableListOf<Map<String, Any?>>()
        val steps = mutableListOf<Map<String, Any?>>()
        val sleep = mutableListOf<Map<String, Any?>>()
        val done = AtomicBoolean(false)

        fun payload() = mapOf(
            "batteryLevel" to batteryLevel,
            "heartRate" to heartRate,
            "spo2" to spo2,
            "steps" to steps,
            "sleep" to sleep,
        )

        fun finish() {
            if (!done.compareAndSet(false, true)) return
            Log.i(
                TAG,
                "sync done hr=${heartRate.size} spo2=${spo2.size} steps=${steps.size} sleep=${sleep.size} battery=$batteryLevel",
            )
            heartRate.lastOrNull()?.let { emitHealth(heartRate = it["bpm"] as? Int) }
            spo2.lastOrNull()?.let { emitHealth(spo2 = it["percentage"] as? Int) }
            steps.lastOrNull()?.let { emitHealth(steps = it["steps"] as? Int) }
            startLiveMetrics()
            reply.success(payload())
        }

        mainHandler.postDelayed({ finish() }, HISTORY_TIMEOUT_MS)

        val afterBattery = AtomicBoolean(false)
        fun continueAfterBattery() {
            if (!afterBattery.compareAndSet(false, true)) return
            readSportThen(steps) {
                readSleepThen(sleep) {
                    readOriginV3(heartRate, spo2, steps, ::finish)
                }
            }
        }

        VPOperateManager.getInstance().readBattery(
            writeResponse,
            IBatteryDataListener { battery ->
                batteryLevel = batteryPercent(battery)
                emitHealth(battery = batteryLevel)
                continueAfterBattery()
            },
        )
        mainHandler.postDelayed({ continueAfterBattery() }, STEP_FALLBACK_MS)
    }

    private fun readSportThen(steps: MutableList<Map<String, Any?>>, next: () -> Unit) {
        val continued = AtomicBoolean(false)
        fun go() {
            if (continued.compareAndSet(false, true)) next()
        }
        VPOperateManager.getInstance().readSportStep(
            writeResponse,
            ISportDataListener { sport ->
                Log.i(TAG, "sport steps=${sport.step}")
                if (sport.step > 0) {
                    steps += mapOf(
                        "date" to todayDate(),
                        "steps" to sport.step,
                        "distanceKm" to sport.dis,
                        "calories" to sport.kcal.toInt(),
                    )
                    emitHealth(steps = sport.step)
                }
                go()
            },
        )
        mainHandler.postDelayed({ go() }, STEP_FALLBACK_MS)
    }

    private fun readSleepThen(sleep: MutableList<Map<String, Any?>>, next: () -> Unit) {
        val continued = AtomicBoolean(false)
        fun go() {
            if (continued.compareAndSet(false, true)) next()
        }
        VPOperateManager.getInstance().readSleepData(
            writeResponse,
            object : ISleepDataListener {
                override fun onSleepDataChange(day: String?, sleepData: SleepData?) {
                    Log.i(TAG, "sleep day=$day data=$sleepData")
                    sleepData?.let { sleep += sleepMap(it) }
                }

                override fun onSleepProgress(progress: Float) {}
                override fun onSleepProgressDetail(day: String?, packagenumber: Int) {}
                override fun onReadSleepComplete() {
                    Log.i(TAG, "sleep read complete count=${sleep.size}")
                    go()
                }
            },
            watchDataDay.coerceIn(1, 7),
        )
        mainHandler.postDelayed({ go() }, SLEEP_FALLBACK_MS)
    }

    private fun readOriginV3(
        heartRate: MutableList<Map<String, Any?>>,
        spo2: MutableList<Map<String, Any?>>,
        steps: MutableList<Map<String, Any?>>,
        finish: () -> Unit,
    ) {
        val continued = AtomicBoolean(false)
        fun go() {
            if (continued.compareAndSet(false, true)) finish()
        }
        VPOperateManager.getInstance().readOriginData(
            writeResponse,
            object : IOriginData3Listener {
                override fun onOriginFiveMinuteListDataChange(originDataList: MutableList<OriginData3>?) {
                    Log.i(TAG, "origin v3 five-min size=${originDataList?.size}")
                    originDataList?.forEach { item ->
                        val recordedAt = timeToIso(item.getmTime()) ?: isoNow()
                        if (item.rateValue in 30..220) {
                            heartRate += mapOf("recordedAt" to recordedAt, "bpm" to item.rateValue)
                        }
                        if (item.stepValue > 0) {
                            steps += mapOf(
                                "date" to (item.date ?: todayDate()),
                                "steps" to item.stepValue,
                                "distanceKm" to item.disValue,
                                "calories" to item.calValue.toInt(),
                            )
                        }
                        lastValid(item.oxygens)?.let { oxygen ->
                            spo2 += mapOf("recordedAt" to recordedAt, "percentage" to oxygen)
                        }
                    }
                }

                override fun onOriginHalfHourDataChange(originHalfHourData: OriginHalfHourData?) {
                    if (originHalfHourData == null) return
                    Log.i(TAG, "origin half-hour steps=${originHalfHourData.allStep}")
                    originHalfHourData.halfHourRateDatas?.forEach { rate ->
                        appendHalfHourRate(heartRate, rate)
                    }
                    originHalfHourData.halfHourSportDatas?.forEach { sport ->
                        appendHalfHourSport(steps, sport, originHalfHourData.date)
                    }
                    if (originHalfHourData.allStep > 0) {
                        steps += mapOf(
                            "date" to (originHalfHourData.date ?: todayDate()),
                            "steps" to originHalfHourData.allStep,
                            "distanceKm" to 0.0,
                            "calories" to 0,
                        )
                    }
                }

                override fun onOriginHRVOriginListDataChange(originHrvDataList: MutableList<HRVOriginData>?) {
                    Log.i(TAG, "origin hrv size=${originHrvDataList?.size}")
                }

                override fun onOriginSpo2OriginListDataChange(originSpo2hDataList: MutableList<Spo2hOriginData>?) {
                    Log.i(TAG, "origin spo2 size=${originSpo2hDataList?.size}")
                    originSpo2hDataList?.forEach { item ->
                        val recordedAt = timeToIso(item.getmTime()) ?: isoNow()
                        if (item.oxygenValue in 70..100) {
                            spo2 += mapOf("recordedAt" to recordedAt, "percentage" to item.oxygenValue)
                        }
                        if (item.heartValue in 30..220) {
                            heartRate += mapOf("recordedAt" to recordedAt, "bpm" to item.heartValue)
                        }
                    }
                }

                override fun onReadOriginProgressDetail(day: Int, date: String?, allPackage: Int, currentPackage: Int) {}
                override fun onReadOriginProgress(progress: Float) {}
                override fun onReadOriginComplete() {
                    Log.i(TAG, "origin v3 complete")
                    go()
                }
                override fun onReadTimeout(day: Int) {
                    Log.w(TAG, "origin v3 timeout day=$day")
                    go()
                }
            },
            watchDataDay.coerceIn(1, 7),
        )
        mainHandler.postDelayed({ go() }, ORIGIN_FALLBACK_MS)
    }

    private fun currentDeviceMap(): Map<String, Any?>? {
        val address = selectedAddress ?: return null
        return mapOf(
            "deviceId" to address,
            "name" to (selectedName ?: "HBand"),
            "macAddress" to address,
            "firmware" to firmware,
            "model" to (modelName ?: "VALDUS / HBand wearable"),
            "batteryLevel" to batteryLevel,
        )
    }

    private fun emitHealth(
        heartRate: Int? = null,
        spo2: Int? = null,
        steps: Int? = null,
        battery: Int? = null,
    ) {
        val payload = mutableMapOf<String, Any?>("recordedAt" to isoNow())
        heartRate?.let { payload["heartRate"] = it }
        spo2?.let { payload["spo2"] = it }
        steps?.let { payload["steps"] = it }
        battery?.let { payload["batteryLevel"] = it }
        if (payload.size == 1) return
        mainHandler.post { healthSink?.success(payload) }
    }

    private fun emitConnection(state: String) {
        mainHandler.post { connectionSink?.success(state) }
    }

    private fun requestEnableBluetooth() {
        if (!hasConnectPermission() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        runCatching {
            activity.startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
        }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        return (activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    }

    private fun isBluetoothEnabled(): Boolean = bluetoothAdapter()?.isEnabled == true

    private fun isLocationEnabled(): Boolean {
        val manager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            Settings.Secure.getInt(activity.contentResolver, Settings.Secure.LOCATION_MODE, 0) !=
                Settings.Secure.LOCATION_MODE_OFF
        }
    }

    private fun hasScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_SCAN) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun clearConnectTimeout() {
        connectTimeout?.let { mainHandler.removeCallbacks(it) }
        connectTimeout = null
    }

    private fun simpleHandler(assign: (EventChannel.EventSink?) -> Unit): EventChannel.StreamHandler {
        return object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) = assign(events)
            override fun onCancel(arguments: Any?) = assign(null)
        }
    }

    private fun once(result: MethodChannel.Result): MethodChannel.Result {
        val replied = AtomicBoolean(false)
        return object : MethodChannel.Result {
            override fun success(value: Any?) {
                if (replied.compareAndSet(false, true)) result.success(value)
            }

            override fun error(code: String, message: String?, details: Any?) {
                if (replied.compareAndSet(false, true)) result.error(code, message, details)
            }

            override fun notImplemented() {
                if (replied.compareAndSet(false, true)) result.notImplemented()
            }
        }
    }

    companion object {
        private const val TAG = "HBandBle"
        private const val METHOD_CHANNEL = "uz.aihealth.mobile/hband_ble"
        private const val SCAN_CHANNEL = "uz.aihealth.mobile/hband_ble_scan"
        private const val CONNECTION_CHANNEL = "uz.aihealth.mobile/hband_ble_connection"
        private const val HEALTH_CHANNEL = "uz.aihealth.mobile/hband_ble_health"
        private const val CONNECT_TIMEOUT_MS = 25_000L
        private const val HISTORY_TIMEOUT_MS = 45_000L
        private const val STEP_FALLBACK_MS = 4_000L
        private const val SLEEP_FALLBACK_MS = 8_000L
        private const val ORIGIN_FALLBACK_MS = 20_000L
        private const val LIVE_STEP_INTERVAL_MS = 45_000L

        private fun isoNow(): String = isoFormat().format(Date())

        private fun todayDate(): String {
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            return sdf.format(Date())
        }

        private fun isoFormat(): SimpleDateFormat {
            return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
        }

        private fun timeToIso(time: TimeData?): String? {
            if (time == null) return null
            val calendar = time.toCalendar() ?: Calendar.getInstance().apply {
                set(time.year, (time.month - 1).coerceAtLeast(0), time.day, time.hour, time.minute, time.second)
            }
            return isoFormat().format(calendar.time)
        }

        private fun batteryPercent(battery: BatteryData?): Int? {
            if (battery == null) return null
            if (battery.isPercent && battery.batteryPercent > 0) return battery.batteryPercent.coerceIn(0, 100)
            if (battery.batteryPercent > 0) return battery.batteryPercent.coerceIn(0, 100)
            return (battery.batteryLevel * 25).coerceIn(0, 100)
        }

        private fun heartBpm(heart: HeartData?): Int? {
            if (heart == null) return null
            val value = heart.data
            val status = heart.heartStatus
            if (status == EHeartStatus.STATE_HEART_WEAR_ERROR ||
                status == EHeartStatus.STATE_LOW_BATTERY ||
                status == EHeartStatus.STATE_INIT ||
                status == EHeartStatus.STATE_HEART_BUSY
            ) {
                return null
            }
            return value.takeIf { it in 30..220 }
        }

        private fun lastValid(values: IntArray?): Int? {
            return values?.lastOrNull { it in 70..100 }
        }

        private fun appendHalfHourRate(
            heartRate: MutableList<Map<String, Any?>>,
            rate: HalfHourRateData,
        ) {
            val bpm = rate.rateValue
            if (bpm !in 30..220) return
            heartRate += mapOf(
                "recordedAt" to (timeToIso(rate.time) ?: isoNow()),
                "bpm" to bpm,
            )
        }

        private fun appendHalfHourSport(
            steps: MutableList<Map<String, Any?>>,
            sport: HalfHourSportData,
            day: String?,
        ) {
            if (sport.stepValue <= 0) return
            steps += mapOf(
                "date" to (sport.date ?: day ?: todayDate()),
                "steps" to sport.stepValue,
                "distanceKm" to sport.disValue,
                "calories" to sport.calValue.toInt(),
            )
        }

        private fun sleepMap(sleepData: SleepData): Map<String, Any?> {
            val precision = sleepData as? SleepPrecisionData
            return mapOf(
                "startedAt" to (timeToIso(sleepData.sleepDown) ?: isoNow()),
                "endedAt" to (timeToIso(sleepData.sleepUp) ?: isoNow()),
                "totalMinutes" to sleepData.allSleepTime,
                "deepMinutes" to sleepData.deepSleepTime,
                "lightMinutes" to sleepData.lowSleepTime,
                "remMinutes" to 0,
                "awakeMinutes" to (precision?.otherDuration ?: 0),
            )
        }
    }
}
