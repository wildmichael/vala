using GLib;

class Maman.Foo : Object {
	public int p1 { get; set; }
	public int p2 { get; set; }
	
	public Foo (int i, construct int p2) {
		p1 = 2 * i;
	}
	
	public static int main (string[] args) {
		stdout.printf ("Construct Formal Parameter Test: 1");
		
		var foo = new Foo (2, 3);
		
		stdout.printf (" 2");
		stdout.printf (" %d", foo.p2);
		stdout.printf (" %d", foo.p1);
		
		stdout.printf (" 5\n");
		
		return 0;
	}
}