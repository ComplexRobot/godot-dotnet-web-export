using Godot;
using Newtonsoft.Json;
using System;
using System.Globalization;

public class TestData
{
    public string Name;
    public int Value;
}

public partial class MainMenu : Control
{
    [Export] public PackedScene Cube;
    [Export] public PackedScene Sphere;
    [Export] public PackedScene Torus;

    private PackedScene _mainScene;

    public override void _Ready()
    {
        float value = 123.45f;
        string str = value.ToString(CultureInfo.InvariantCulture);
        GD.Print(str);   // Safe
        GD.Print(value); // Crashes

        var obj = new TestData { Name = "Test", Value = 42 };
        string json = JsonConvert.SerializeObject(obj);   // Works in editor / desktop
        var back = JsonConvert.DeserializeObject<TestData>(json); // Aborts in Web

        GD.Print(back);
        GD.Print(json);

        _mainScene = ResourceLoader.Load<PackedScene>("res://main.tscn");
        GetNode<Button>("VBoxContainer/Cube").Pressed += () => ChangeToMainAndSpawn(Cube.Instantiate());
        GetNode<Button>("VBoxContainer/Sphere").Pressed += () => ChangeToMainAndSpawn(Sphere.Instantiate());
        GetNode<Button>("VBoxContainer/Torus").Pressed += () => ChangeToMainAndSpawn(Torus.Instantiate());
    }

    private void ChangeToMainAndSpawn(Node node)
    {
        var callable = Callable.From<Node>((sender) =>
        {
            if (sender is Main mainScene)
            {
                mainScene.Spawn(node);
            }
        });
        GetTree().Root.Connect(Node.SignalName.ChildEnteredTree, callable, (uint)ConnectFlags.OneShot);
        GetTree().ChangeSceneToPacked(_mainScene);
    }
}