extends Node
class_name MarketplaceSDK

var GATEWAY_URL: String = ""
var anon_key: String = ""


var _package_name: String
var _current_player_id: String = ""
# --- THÊM KHÓA NÀY ĐỂ CHỐNG DOUBLE REQUEST ---
var _is_requesting: bool = false 

func _ready() -> void:
	# Tự động lấy Package Name định danh game
	_package_name = "com.godot.game." + ProjectSettings.get_setting("application/config/name").to_lower().replace(" ", "")
	_load_s_market()
	print("pack name", _package_name )
# Developer gọi hàm này để gán ID người chơi sau khi hệ thống của họ tự login thành công
func initialize_player_session(player_id: String) -> void:
	_current_player_id = player_id
	
	print("SDK: Đã khởi tạo phiên làm việc cho PlayerID: ", player_id)

func _send_request(payload: Dictionary) -> Dictionary:
	# Nếu đang có một request khác đang chạy ngầm, chặn ngay lập tức
	if _is_requesting:
		print("[SDK Warning] Đang có request khác đang xử lý, chặn cuộc gọi trùng lập!")
		return {"error": "Pending", "message": "Hệ thống đang xử lý tác vụ trước."}
		
	_is_requesting = true # Bật khóa bảo vệ
	# Tự động chèn player_id vào mọi payload gửi lên hệ thống
	if not _current_player_id.is_empty() and not payload.has("player_id"):
		payload["player_id"] = _current_player_id

	var headers = [
		"Content-Type: application/json",
		"X-Package-Name: " + _package_name,
		"apikey: " + anon_key
	]
		
	var http_request = HTTPRequest.new()
	add_child(http_request)
	var err = http_request.request(GATEWAY_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http_request.queue_free()
		return {"error": "Mạng lỗi"}
		
	var response = await http_request.request_completed
	http_request.queue_free()
	
	_is_requesting = false # TÁC VỤ HOÀN THÀNH -> MỞ KHÓA CHO LƯỢT TIẾP THEO
	
	var response_code = response[1]
	var body_string = response[3].get_string_from_utf8()
	
	var json = JSON.new()
	if json.parse(body_string) == OK:
		return json.get_data()
	return {
		"error": "Lỗi phân tích dữ liệu", "raw_body": body_string
		}

# ==============================================================================
# BỘ CÁC HÀM CÔNG KHAI (PUBLIC API)
# ==============================================================================

func search_marketplace(search_text: String = "") -> Dictionary:
	return await _send_request({"action": "search", "search_query": search_text})

func listing_item(platform_price: float, item_metadata: Dictionary) -> Dictionary:
	return await _send_request({"action": "list", "price": platform_price, "item_metadata": item_metadata})

func purchase_item(listing_id: String, is_game_currency: bool = false) -> Dictionary:
	var payload = {
		"action": "purchase", 
		"listing_id": listing_id,
		"is_game_currency": is_game_currency
	}
	return await _send_request(payload)

func get_player_dashboard_data() -> Dictionary:
	return await _send_request({"action": "get_dashboard"})

func claim_item_to_game(inventory_id: String) -> Dictionary:
	return await _send_request({"action": "claim", "inventory_id": inventory_id})
# TẠO MỚI: HÀM HỦY ĐĂNG BÁN VẬT PHẨM (CANCEL LISTING)
func cancel_listing(listing_id: String) -> Dictionary:
	var payload = {
		"action": "cancel",
		"listing_id": listing_id
	}
	return await _send_request(payload)

func _load_s_market() -> void:
	var config = ConfigFile.new()
	# Giải mã file nhị phân bằng mật khẩu bạn đã đặt ở bước 1
	var err = config.load_encrypted_pass("res://addons/smarket/sdk_data.res", "mat_khau_giai_ma_resource")

	if err == OK:
		var base64_key = config.get_value("auth", "ankey", "")
		var base64_url = config.get_value("auth", "url", "")
		# Chuyển đổi ngược từ Base64 về chuỗi ban đầu
		var ankey = Marshalls.base64_to_variant(base64_key)
		var url = Marshalls.base64_to_variant(base64_url)
		print("key and url", ankey, url)
		#todo
		#_package_name = "com.godot.game.testmarket"
	# --- BỔ SUNG DÒNG NÀY VÀO SCRIPT TEST CỦA BẠN ---
		anon_key = ankey
		GATEWAY_URL = url
	else:
		push_error("Không thể tải dữ liệu core của SDK!")
