/* gstreamer-controller-0.10.vapi generated by lt-vapigen, do not modify. */

[CCode (cprefix = "Gst", lower_case_cprefix = "gst_")]
namespace Gst {
	[CCode (cprefix = "GST_INTERPOLATE_", cheader_filename = "gst/controller/gstcontroller.h")]
	public enum InterpolateMode {
		NONE,
		TRIGGER,
		LINEAR,
		QUADRATIC,
		CUBIC,
		USER,
	}
	[CCode (cprefix = "", cheader_filename = "gst/controller/gstlfocontrolsource.h")]
	public enum LFOWaveform {
		Sine waveform (default),
		Square waveform,
		Saw waveform,
		Reverse saw waveform,
		Triangle waveform,
	}
	[CCode (cheader_filename = "gst/controller/gstcontroller.h")]
	public class TimedValue {
		public weak Gst.ClockTime timestamp;
		public weak GLib.Value value;
	}
	[CCode (cheader_filename = "gst/controller/gstcontroller.h")]
	public class ValueArray {
		public weak string property_name;
		public int nbsamples;
		public weak Gst.ClockTime sample_interval;
		public pointer values;
	}
	[CCode (cheader_filename = "gst/controller/gstcontroller.h")]
	public class ControlSource : GLib.Object {
		public bool bound;
		public bool bind (GLib.ParamSpec pspec);
		public bool get_value (Gst.ClockTime timestamp, GLib.Value value);
		public bool get_value_array (Gst.ClockTime timestamp, Gst.ValueArray value_array);
	}
	[CCode (cheader_filename = "gst/controller/gstcontroller.h")]
	public class Controller : GLib.Object {
		public weak GLib.List properties;
		public weak GLib.Mutex @lock;
		public weak GLib.Object object;
		public weak GLib.Value get (string property_name, Gst.ClockTime timestamp);
		public weak GLib.List get_all (string property_name);
		public weak Gst.ControlSource get_control_source (string property_name);
		public bool get_value_array (Gst.ClockTime timestamp, Gst.ValueArray value_array);
		public bool get_value_arrays (Gst.ClockTime timestamp, GLib.SList value_arrays);
		public static bool init (int argc, out weak string argv);
		public Controller (GLib.Object object);
		public Controller.list (GLib.Object object, GLib.List list);
		public Controller.valist (GLib.Object object, pointer var_args);
		public bool remove_properties ();
		public bool remove_properties_list (GLib.List list);
		public bool remove_properties_valist (pointer var_args);
		public bool set (string property_name, Gst.ClockTime timestamp, GLib.Value value);
		public bool set_control_source (string property_name, Gst.ControlSource csource);
		public void set_disabled (bool disabled);
		public bool set_from_list (string property_name, GLib.SList timedvalues);
		public bool set_interpolation_mode (string property_name, Gst.InterpolateMode mode);
		public void set_property_disabled (string property_name, bool disabled);
		public weak Gst.ClockTime suggest_next_sync ();
		public bool sync_values (Gst.ClockTime timestamp);
		public bool unset (string property_name, Gst.ClockTime timestamp);
		public bool unset_all (string property_name);
		[NoAccessorMethod]
		public weak uint64 control_rate { get; set; }
	}
	[CCode (cheader_filename = "gst/controller/gstcontroller.h")]
	public class InterpolationControlSource : Gst.ControlSource {
		public weak GLib.Mutex @lock;
		public weak GLib.List get_all ();
		public int get_count ();
		public InterpolationControlSource ();
		public bool set (Gst.ClockTime timestamp, GLib.Value value);
		public bool set_from_list (GLib.SList timedvalues);
		public bool set_interpolation_mode (Gst.InterpolateMode mode);
		public bool unset (Gst.ClockTime timestamp);
		public void unset_all ();
	}
	[CCode (cheader_filename = "gst/controller/gstlfocontrolsource.h")]
	public class LFOControlSource : Gst.ControlSource {
		public weak GLib.Mutex @lock;
		public LFOControlSource ();
		[NoAccessorMethod]
		public weak GLib.Value amplitude { get; set; }
		[NoAccessorMethod]
		public weak double frequency { get; set; }
		[NoAccessorMethod]
		public weak GLib.Value offset { get; set; }
		[NoAccessorMethod]
		public weak uint64 timeshift { get; set; }
		[NoAccessorMethod]
		public weak Gst.LFOWaveform waveform { get; set; }
	}
	public static delegate bool ControlSourceBind (Gst.ControlSource self, GLib.ParamSpec pspec);
	public static delegate bool ControlSourceGetValue (Gst.ControlSource self, Gst.ClockTime timestamp, GLib.Value value);
	public static delegate bool ControlSourceGetValueArray (Gst.ControlSource self, Gst.ClockTime timestamp, Gst.ValueArray value_array);
	public const int PARAM_CONTROLLABLE;
	public static weak Gst.Controller object_control_properties (GLib.Object object);
	public static weak Gst.ClockTime object_get_control_rate (GLib.Object object);
	public static weak Gst.ControlSource object_get_control_source (GLib.Object object, string property_name);
	public static weak Gst.Controller object_get_controller (GLib.Object object);
	public static bool object_get_value_array (GLib.Object object, Gst.ClockTime timestamp, Gst.ValueArray value_array);
	public static bool object_get_value_arrays (GLib.Object object, Gst.ClockTime timestamp, GLib.SList value_arrays);
	public static void object_set_control_rate (GLib.Object object, Gst.ClockTime control_rate);
	public static bool object_set_control_source (GLib.Object object, string property_name, Gst.ControlSource csource);
	public static bool object_set_controller (GLib.Object object, Gst.Controller controller);
	public static weak Gst.ClockTime object_suggest_next_sync (GLib.Object object);
	public static bool object_sync_values (GLib.Object object, Gst.ClockTime timestamp);
	public static bool object_uncontrol_properties (GLib.Object object);
}
