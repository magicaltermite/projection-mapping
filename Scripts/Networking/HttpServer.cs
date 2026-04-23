using Godot;

namespace ProjectionMapping.Scripts.Networking;

public partial class HttpServer : Node
{
	public override void _Ready() {
		var gdHttpServer =
			GD.Load<GDScript>(
				"C:/Users/marku/Desktop/Mappe 1/SDU/8 Semester/Metaverse/projection-mapping/backend/addons/godottpd/http_server.gd");
		var server = (HttpServer)gdHttpServer.New();
		
	}
}