import Toybox.Activity;
import Toybox.Application;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class WalkingPadField extends WatchUi.DataField {
    private var _fSpeed as FitContributor.Field?;
    private var _fDist as FitContributor.Field?;
    private var _fSteps as FitContributor.Field?;
    private var _fDistTot as FitContributor.Field?;
    private var _fStepsTot as FitContributor.Field?;
    private var _fTime as FitContributor.Field?;
    private var _lastSpeed as Float = -1.0f;

    function initialize() {
        DataField.initialize();
        try {
            _fSpeed = createField("pad_speed", 0, FitContributor.DATA_TYPE_FLOAT,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "km/h"});
            _fDist = createField("pad_dist", 1, FitContributor.DATA_TYPE_FLOAT,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "m"});
            _fSteps = createField("pad_steps", 2, FitContributor.DATA_TYPE_UINT32,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "steps"});
            _fDistTot = createField("pad_dist_total", 3, FitContributor.DATA_TYPE_UINT32,
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "m"});
            _fStepsTot = createField("pad_steps_total", 4, FitContributor.DATA_TYPE_UINT32,
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "steps"});
            _fTime = createField("pad_time", 5, FitContributor.DATA_TYPE_UINT32,
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s"});
        } catch (e instanceof Lang.Exception) {
            var m = e.getErrorMessage();
            PadState.lastName = "E2:" + (m != null ? m : "?");
        }
    }

    //! compute() runs ~1 Hz while the field is on screen: poll the
    //! pad and push the latest values into the FIT fields.
    function compute(info as Info) as Numeric or Duration or String or Null {
        if (PadState.ble != null) {
            PadState.ble.pollStats();
        }
        try {
            if (PadState.speed != _lastSpeed && _fSpeed != null) {
                _lastSpeed = PadState.speed;
                _fSpeed.setData(_lastSpeed);
            }
            if (_fDist != null) {
                _fDist.setData(PadState.distance.toFloat());
            }
            if (_fSteps != null) {
                _fSteps.setData(PadState.steps);
            }
            if (_fDistTot != null) {
                _fDistTot.setData(PadState.distance);
            }
            if (_fStepsTot != null) {
                _fStepsTot.setData(PadState.steps);
            }
            if (_fTime != null) {
                _fTime.setData(PadState.time);
            }
        } catch (e instanceof Lang.Exception) {
            var m = e.getErrorMessage();
            PadState.lastName = "E3:" + (m != null ? m : "?");
        }
        return null;
    }

    function onUpdate(dc as Dc) as Void {
        var bg = getBackgroundColor();
        var fg = bg == Graphics.COLOR_BLACK ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(bg, bg);
        dc.clear();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        var w = dc.getWidth();
        var x = w / 2;

        if (PadState.status != 2) {
            var msg = PadState.status == 0
                ? "P" + PadState.reg + " S" + PadState.scan + "/" + PadState.serr
                    + " N" + PadState.seen + " " + PadState.lastName
                : "Connecting";
            dc.drawText(x, dc.getHeight() / 2, Graphics.FONT_XTINY, msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var s = PadState.time % 60;
        var m = (PadState.time / 60) % 60;
        var h = PadState.time / 3600;
        var t = h > 0
            ? h.toString() + ":" + m.format("%02d") + ":" + s.format("%02d")
            : m.toString() + ":" + s.format("%02d");

        var fLabel = Graphics.FONT_XTINY;
        var fBig = Graphics.FONT_NUMBER_MILD;
        var fMid = Graphics.FONT_MEDIUM;

        var y = (dc.getHeight() * 0.16).toNumber();
        dc.drawText(x, y, fLabel, "Speed", Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(fLabel);
        dc.drawText(x, y, fBig, PadState.speed.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(fBig);
        dc.drawText(x, y, fLabel, "km/h", Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(fLabel) + (dc.getHeight() * 0.05).toNumber();
        dc.drawText(x, y, fMid,
            (PadState.distance / 1000.0f).format("%.2f") + " km  " + PadState.steps + " st",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(fMid);
        dc.drawText(x, y, fMid, t, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
