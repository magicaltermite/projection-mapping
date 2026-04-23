using Godot;

namespace ProjectionMapping.Scripts;

public partial class Main : Node3D
{
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		// For getting rid of rancid error.
		CallDeferred(nameof(SetNavMapCellSize));
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
	}
	
	private void SetNavMapCellSize()
	{
		Rid mapRid = GetWorld3D().NavigationMap;
		NavigationServer3D.MapSetCellSize(mapRid, 0.08f);
		GD.Print("Nav map cell size set to: ", NavigationServer3D.MapGetCellSize(mapRid));
	}
}
