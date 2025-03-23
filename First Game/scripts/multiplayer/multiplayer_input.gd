extends MultiplayerSynchronizer

@onready var player = $".."

var input_direction
var username = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	input_direction = Input.get_axis("move_left", "move_right")
	
	username = SteamManager.steam_username

func _physics_process(delta):
	input_direction = Input.get_axis("move_left", "move_right")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("jump"):
		# 本地处理跳跃
		player.do_jump = true
		# 通知其他玩家
		jump.rpc()

@rpc("call_local", "reliable")
func jump():
	# 只更新其他客户端的跳跃状态，本地已处理
	if multiplayer.get_unique_id() != get_multiplayer_authority():
		player.do_jump = true
