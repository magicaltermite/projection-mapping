using Godot;

namespace ProjectionMapping.Scripts.Objects;

public partial class Projector : Node
{
	// Positional variables, used for determining the projectors exact location
	private float Latitude { get; set; }
	private float Longitude { get; set; }
	private float Elevation { get; set; } // Height over sea level
	
	// Rotation
	private float RotX { get; set; }
	private float RotY { get; set; }
	private float RotZ { get; set; }
}