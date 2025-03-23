extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0

@onready var animated_sprite = $AnimatedSprite2D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var direction = 1
var do_jump = false
var _is_on_floor = true
var alive = true
var last_sync_position = Vector2()
var server_position = Vector2()

@onready var username_label = $Username
var username = ""
var rtt = 0 # 往返时间(延迟)

@export var player_id := 1:
	set(id):
		player_id = id
		%InputSynchronizer.set_multiplayer_authority(id)

func _ready():
	if multiplayer.get_unique_id() == player_id:
		$Camera2D.make_current()
		# 本地玩家创建延迟显示UI
		_create_latency_ui()
	else:
		$Camera2D.enabled = false
	
	# 创建位置同步计时器
	if not has_node("SyncTimer"):
		var sync_timer = Timer.new()
		sync_timer.name = "SyncTimer"
		sync_timer.wait_time = 0.1 # 每0.1秒同步一次
		sync_timer.autostart = true
		sync_timer.timeout.connect(_on_sync_timer_timeout)
		add_child(sync_timer)

func _apply_animations(delta):
	# Flip the Sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	
	# Play animations
	if _is_on_floor:
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")

func _apply_movement_from_input(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if do_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		do_jump = false

	# Get the input direction: -1, 0, 1
	direction = %InputSynchronizer.input_direction
	
	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	username = %InputSynchronizer.username
	_is_on_floor = is_on_floor()

func _physics_process(delta):
	# 本地客户端自己负责移动计算和显示
	if multiplayer.get_unique_id() == player_id:
		if not alive && is_on_floor():
			_set_alive()
		
		_apply_movement_from_input(delta)
		_apply_animations(delta)
		
		# 定期同步位置到服务器
		if position.distance_to(last_sync_position) > 5.0:
			sync_position_to_server.rpc_id(1, position, velocity)
			last_sync_position = position
		
	# 非本地客户端和服务器模式
	elif not multiplayer.is_server() || MultiplayerManager.host_mode_enabled:
		_apply_animations(delta)
		
	# 显示用户名
	if username_label && username != "":
		username_label.set_text(username)
		
	# 更新延迟显示
	if multiplayer.get_unique_id() == player_id && has_node("LatencyUI"):
		$LatencyUI/Label.text = "延迟: %s ms" % rtt

func _on_sync_timer_timeout():
	# 服务器：向所有客户端广播位置
	if multiplayer.is_server():
		sync_position_to_clients.rpc(position, velocity)
	
	# 本地玩家：发送ping测量延迟
	if multiplayer.get_unique_id() == player_id:
		ping_server.rpc_id(1, Time.get_ticks_msec())

@rpc("any_peer", "call_local")
func sync_position_to_server(client_position, client_velocity):
	# 仅服务器处理
	if not multiplayer.is_server():
		return
		
	# 可以在此添加验证逻辑
	# ...
	
	# 接受客户端位置
	position = client_position
	velocity = client_velocity

@rpc
func sync_position_to_clients(server_position, server_velocity):
	# 非本地玩家才需要同步位置
	if multiplayer.get_unique_id() != player_id:
		# 使用tween平滑过渡
		var tween = create_tween()
		tween.tween_property(self, "position", server_position, 0.1)
		tween.tween_property(self, "velocity", server_velocity, 0.1)

@rpc("any_peer")
func ping_server(client_time):
	# 服务器收到ping后立即回应
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		pong_client.rpc_id(sender_id, client_time)

@rpc
func pong_client(client_time):
	# 计算往返时间
	rtt = Time.get_ticks_msec() - client_time

func _create_latency_ui():
	# 创建延迟显示UI
	if has_node("LatencyUI"):
		return
		
	var ui = Control.new()
	ui.name = "LatencyUI"
	ui.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ui.position = Vector2(0, 0)
	
	var label = Label.new()
	label.name = "Label"
	label.text = "延迟: 0 ms"
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	
	ui.add_child(label)
	add_child(ui)

func mark_dead():
	print("Mark player dead!")
	alive = false
	$CollisionShape2D.set_deferred("disabled", true)
	$RespawnTimer.start()

func _respawn():
	print("Respawned!")
	position = MultiplayerManager.respawn_point
	$CollisionShape2D.set_deferred("disabled", false)

func _set_alive():
	print("alive again!")
	alive = true
	Engine.time_scale = 1.0





