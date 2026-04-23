using Godot;
using System;

public partial class DrawPath : Node3D
{
	Rid _defaultMapRid;
	[Export]
	public Node3D[] _PathNodes { get; set; }
	[Export]
	public NavigationRegion3D NavRegion { get; set; }
	
	// Called when the node enters the scene tree for the first time.
	public async override void _Ready()
	{		
		_defaultMapRid = NavRegion.GetNavigationMap();
		while (true)
		{
			await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
			Vector3 test = NavigationServer3D.MapGetClosestPoint(_defaultMapRid, _PathNodes[0].GlobalPosition);
			GD.Print($"Polling snapped: {test}");
			if (test != Vector3.Zero) break;
		}
		GD.Print($"Map valid: {NavigationServer3D.MapIsActive(_defaultMapRid)}");
		
		DrawThePath();
	}
	
	void DrawThePath()
	{
		Vector3 startPosition = _PathNodes[0].GlobalPosition;
		Vector3 targetPosition = _PathNodes[1].GlobalPosition;

		Vector3 snappedStart = NavigationServer3D.MapGetClosestPoint(_defaultMapRid, startPosition);
		Vector3 snappedTarget = NavigationServer3D.MapGetClosestPoint(_defaultMapRid, targetPosition);

		GD.Print($"Regions: {NavigationServer3D.MapGetRegions(_defaultMapRid).Count}");
		GD.Print($"Start: {startPosition} -> Snapped: {snappedStart}");
		GD.Print($"Target: {targetPosition} -> Snapped: {snappedTarget}");
		GD.Print($"NavMesh null: {NavRegion.NavigationMesh == null}");
		GD.Print($"NavMesh vertex count: {NavRegion.NavigationMesh?.GetVertices().Length}");

		Vector3[] pathToDraw = GetNavigationPath(startPosition, targetPosition);
		GD.Print($"Path length: {pathToDraw.Length}");
		DrawNavigationPath(pathToDraw);
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta) {}
	
	Vector3[] GetNavigationPath(Vector3 startPosition, Vector3 targetPosition)
	{
		if (!IsInsideTree())
		{
			GD.Print("Not inside tree.");
			return Array.Empty<Vector3>();
		}

		Vector3[] path = NavigationServer3D.MapGetPath(
			_defaultMapRid,
			startPosition,
			targetPosition,
			true
		);
		return path;
	}
	
	void DrawNavigationPath(Vector3[] currentPath)
	{
		for (int i = 0; i < currentPath.Length - 1; i++)
		{
			Line(currentPath[i], currentPath[i + 1]);
		}
	}
	
	async void Line(Vector3 from, Vector3 to, float persistenceMs = 9999)
	{
		var meshInstance = new MeshInstance3D();
		var immediateMesh = new ImmediateMesh();
		var material = new OrmMaterial3D();

		meshInstance.Mesh = immediateMesh;
		meshInstance.CastShadow = GeometryInstance3D.ShadowCastingSetting.Off;

		immediateMesh.SurfaceBegin(Mesh.PrimitiveType.Lines, material);
		immediateMesh.SurfaceAddVertex(from);
		immediateMesh.SurfaceAddVertex(to);
		immediateMesh.SurfaceEnd();

		material.ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded;
		material.AlbedoColor = Colors.White;

		GetTree().Root.AddChild(meshInstance);

		if (persistenceMs == 0)
		{
			await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
			meshInstance.QueueFree();
		}
		else if (persistenceMs > 0)
		{
			await ToSignal(GetTree().CreateTimer(persistenceMs), Timer.SignalName.Timeout);
			meshInstance.QueueFree();
		}
	}
}
