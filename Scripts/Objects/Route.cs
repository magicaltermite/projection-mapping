using Godot;

namespace ProjectionMapping.Scripts.Objects;

public partial class Route : Node
{
	private int _routeId;
	
	private Vector3 _currentPosition; // The current position of the user
	private Vector3 _endPosition;
}