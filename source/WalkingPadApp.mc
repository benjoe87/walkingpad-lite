import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Latest values reported by the treadmill, shared between the BLE
// delegate and the data field. Module vars avoid passing object
// references around (memory is tight on this device).
module PadState {
    var speed as Float = 0.0f;       // km/h
    var distance as Number = 0;      // meters
    var steps as Number = 0;
    var time as Number = 0;          // elapsed seconds on the pad
    var status as Number = 0;        // 0=scanning 1=connecting 2=connected
    var seen as Number = 0;          // BLE results received (debug)
    var lastName as String = "";     // last advertised name (debug)
    var reg as Number = -1;          // onProfileRegister status (debug)
    var scan as Number = -1;         // scanState (debug)
    var serr as Number = -1;         // scan status (debug)
    var ble as PadBleDelegate?;
}

class WalkingPadApp extends Application.AppBase {
    private var _delegate as PadBleDelegate?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        System.println("wp onstart");
        try {
            _delegate = new PadBleDelegate();
            PadState.ble = _delegate;
            BluetoothLowEnergy.setDelegate(_delegate);
            _delegate.register();
        } catch (e instanceof Lang.Exception) {
            var m = e.getErrorMessage(); PadState.lastName = "E1:" + (m != null ? m : "?");
        }
    }

    function onStop(state as Dictionary?) as Void {
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        _delegate = null;
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new WalkingPadField()];
    }
}
