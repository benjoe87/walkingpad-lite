import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;

//! BLE handling for the classic KingSmith WalkingPad protocol
//! (service 0xFE00, notify 0xFE01, write 0xFE02) used by the
//! R1 Pro / R2 Pro family.
class PadBleDelegate extends BluetoothLowEnergy.BleDelegate {
    const SVC    = BluetoothLowEnergy.stringToUuid("0000FE00-0000-1000-8000-00805F9B34FB");
    const CHR_IN = BluetoothLowEnergy.stringToUuid("0000FE01-0000-1000-8000-00805F9B34FB");
    const CHR_OUT = BluetoothLowEnergy.stringToUuid("0000FE02-0000-1000-8000-00805F9B34FB");

    const PROFILE = {
        :uuid => SVC,
        :characteristics => [
            {:uuid => CHR_IN, :descriptors => [BluetoothLowEnergy.cccdUuid()]},
            {:uuid => CHR_OUT}
        ]
    };

    // F7 A2 <cmd> <param> <crc> FD, crc = (0xA2 + cmd + param) & 0xFF
    const ASK_STATS = [0xF7, 0xA2, 0x00, 0x00, 0xA2, 0xFD]b;

    private var _chrIn as Characteristic?;
    private var _chrOut as Characteristic?;
    private var _queue as Array = [];

    function initialize() {
        BleDelegate.initialize();
    }

    function register() as Void {
        System.println("wp register");
        BluetoothLowEnergy.registerProfile(PROFILE);
        startScan();
    }

    function onProfileRegister(uuid as Uuid, status as Status) as Void {
        PadState.reg = status;
        System.println("wp profile " + status);
        startScan();
    }

    function onScanStateChange(scanState as ScanState, status as Status) as Void {
        PadState.scan = scanState;
        PadState.serr = status;
        System.println("wp scanstate " + scanState + "/" + status);
        if (PadState.status != 2) {
            PadState.status = scanState == BluetoothLowEnergy.SCAN_STATE_SCANNING ? 0 : 1;
        }
    }

    function onScanResults(scanResults as Iterator) as Void {
        try {
        for (var r = scanResults.next(); r != null; r = scanResults.next()) {
            if (r instanceof ScanResult) {
            PadState.seen++;
            var nm = (r as ScanResult).getDeviceName();
            if (nm != null) {
                PadState.lastName = nm;
            }
            if (PadState.seen == 1) {
                System.println("wp first result " + nm);
            }
            if (hasPadService(r as ScanResult)) {
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
                PadState.status = 1;
                System.println("wp pairing " + nm);
                if (BluetoothLowEnergy.pairDevice(r) == null) {
                    startScan();
                }
                return;
            }
            }
        }
        } catch (e instanceof Lang.Exception) {
            var m = e.getErrorMessage();
            PadState.lastName = "E4:" + (m != null ? m : "?");
        }
    }

    function onConnectedStateChanged(device as Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        System.println("wp connstate " + state);
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            var svc = device.getService(SVC);
            if (svc != null) {
                _chrIn = svc.getCharacteristic(CHR_IN);
                _chrOut = svc.getCharacteristic(CHR_OUT);
                var cccd = _chrIn != null ? _chrIn.getDescriptor(BluetoothLowEnergy.cccdUuid()) : null;
                if (cccd != null) {
                    cccd.requestWrite([0x01, 0x00]b);
                }
                PadState.status = 2;
            }
        } else {
            dropConnection();
            startScan();
        }
    }

    function onDescriptorWrite(descriptor as Descriptor, status as Status) as Void {
        System.println("wp desc " + status);
        pollStats();
    }

    function onCharacteristicChanged(characteristic as Characteristic, value as ByteArray) as Void {
        if (!characteristic.getUuid().equals(CHR_IN) || value.size() < 14
            || value[0] != 0xF8 || value[1] != 0xA2) {
            if (PadState.seen < 900000) { System.println("wp chg bad " + value.size()); }
            return;
        }
        // F8 A2 state speed mode t[3] d[3] s[3] ...  (all big-endian)
        PadState.speed = value[3] / 10.0f;
        PadState.time = (value[5] << 16) | (value[6] << 8) | value[7];
        PadState.distance = ((value[8] << 16) | (value[9] << 8) | value[10]) * 10;
        PadState.steps = (value[11] << 16) | (value[12] << 8) | value[13];
    }

    //! Called ~1 Hz from the field's compute(). Sends one queued
    //! command frame per call (the pad drops back-to-back frames,
    //! they need spacing), otherwise polls the status.
    function pollStats() as Void {
        if (_chrOut == null) {
            return;
        }
        if (_queue.size() > 0) {
            _chrOut.requestWrite(_queue[0] as ByteArray, {:writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT});
            _queue = _queue.slice(1, null);
        } else {
            _chrOut.requestWrite(ASK_STATS, {:writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT});
        }
    }

    //! Queue the belt start sequence: manual mode, start, set speed.
    //! The continuous ASK_STATS polling already keeps the app-control
    //! path awake, so no leading stats frame is needed here.
    function startBelt(speedX10 as Number) as Void {
        _queue.add([0xF7, 0xA2, 0x02, 0x01, 0xA5, 0xFD]b);  // mode manual
        _queue.add([0xF7, 0xA2, 0x04, 0x01, 0xA7, 0xFD]b);  // start belt
        if (speedX10 > 0) {
            var crc = (0xA2 + 0x01 + speedX10) & 0xFF;
            _queue.add([0xF7, 0xA2, 0x01, speedX10, crc, 0xFD]b);  // set speed
        }
    }

    function stopBelt() as Void {
        _queue.add([0xF7, 0xA2, 0x01, 0x00, 0xA3, 0xFD]b);  // speed = 0 stops belt
    }



    private function startScan() as Void {
        PadState.status = 0;
        try {
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        } catch (e instanceof Lang.Exception) {
            PadState.serr = 99;
        }
    }

    private function dropConnection() as Void {
        PadState.status = 0;
        _chrIn = null;
        _chrOut = null;
    }

    private function hasPadService(r as ScanResult) as Boolean {
        var uuids = r.getServiceUuids();
        for (var u = uuids.next(); u != null; u = uuids.next()) {
            if (u.equals(SVC)) {
                return true;
            }
        }
        var name = r.getDeviceName();
        if (name == null) {
            return false;
        }
        var keys = ["alkingPad", "ALKINGPAD", "KINGSMITH", "Kingsmith", "KS-", "DYNAMAX", "R2", "TREAD"];
        for (var i = 0; i < keys.size(); i++) {
            if (name.find(keys[i]) != null) {
                return true;
            }
        }
        return false;
    }
}
