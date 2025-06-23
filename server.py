import os
import time
import logging
import hashlib
import json
import base64
import hmac
import requests
import falcon
from falcon import Request, Response

logging.basicConfig(level='INFO')

# Данные вашего ТЕРМИНАЛА:
TINKOFF_TERMINAL_KEY = "1738406729695"
TINKOFF_SECRET_KEY   = "7o^3fOanam^4AX_Z"

def make_tinkoff_token(data: dict) -> str:
    """
    Формирует токен для запроса к Tinkoff /Init:
      - Удаляет ключ 'Token'
      - Добавляет data["Password"] = TINKOFF_SECRET_KEY
      - Для расчёта токена используются только скалярные (не dict и не list) значения
      - Сортирует ключи по алфавиту, конкатенирует их строковые значения и вычисляет SHA256.
    """
    data = data.copy()
    if "Token" in data:
        del data["Token"]
    data["Password"] = TINKOFF_SECRET_KEY

    # Фильтруем только скалярные значения
    filtered = {k: v for k, v in data.items() if not isinstance(v, (dict, list))}
    keys_sorted = sorted(filtered.keys())
    concatenated = "".join(str(filtered[k]) for k in keys_sorted)
    return hashlib.sha256(concatenated.encode("utf-8")).hexdigest()

def encode_token(data: dict, secret: str) -> str:
    """
    Кодирует данные в stateless-токен вида:
      base64url(json_data).base64url(signature)
    """
    json_data = json.dumps(data, separators=(',', ':')).encode('utf-8')
    b64_data = base64.urlsafe_b64encode(json_data).rstrip(b'=')
    signature = hmac.new(secret.encode('utf-8'), json_data, hashlib.sha256).digest()
    b64_signature = base64.urlsafe_b64encode(signature).rstrip(b'=')
    return b64_data.decode('utf-8') + "." + b64_signature.decode('utf-8')

def decode_token(token: str, secret: str) -> dict:
    try:
        b64_data, b64_signature = token.split(".")
        pad = '=' * (-len(b64_data) % 4)
        json_data = base64.urlsafe_b64decode(b64_data + pad)
        pad_sig = '=' * (-len(b64_signature) % 4)
        signature = base64.urlsafe_b64decode(b64_signature + pad_sig)
        expected_signature = hmac.new(secret.encode('utf-8'), json_data, hashlib.sha256).digest()
        if not hmac.compare_digest(signature, expected_signature):
            raise Exception("Invalid token signature")
        return json.loads(json_data.decode('utf-8'))
    except Exception as e:
        raise Exception("Token decoding error: " + str(e))

# -------------------- Статичные страницы --------------------
class StaticFolder:
    def on_get(self, req: Request, resp: Response, path):
        file_path = os.path.join("server", "static", path)
        if os.path.exists(file_path):
            if file_path.lower().endswith(".png"):
                resp.content_type = "image/png"
            elif file_path.lower().endswith(".jpg"):
                resp.content_type = "image/jpeg"
            elif file_path.lower().endswith(".css"):
                resp.content_type = "text/css"
            else:
                resp.content_type = "application/octet-stream"
            with open(file_path, "rb") as f:
                resp.data = f.read()
            resp.status = falcon.HTTP_200
        else:
            resp.status = falcon.HTTP_404

class MainPage:
    def on_get(self, req: Request, resp: Response):
        if not os.path.exists("pidorpay2.html"):
            resp.text = "File pidorpay2.html not found!"
            resp.status = falcon.HTTP_404
            return
        resp.content_type = "text/html; charset=utf-8"
        with open("pidorpay2.html", "r", encoding="utf-8") as f:
            resp.text = f.read()
        resp.status = falcon.HTTP_200

class Offer:
    def on_get(self, req: Request, resp: Response):
        resp.content_type = "text/html; charset=utf-8"
        if os.path.exists("offer.html"):
            resp.text = open("offer.html", "r", encoding='utf-8').read()
            resp.status = falcon.HTTP_200
        else:
            resp.text = "offer.html not found!"
            resp.status = falcon.HTTP_404

class Policy:
    def on_get(self, req: Request, resp: Response):
        resp.content_type = "text/html; charset=utf-8"
        if os.path.exists("policy.html"):
            resp.text = open("policy.html", "r", encoding='utf-8').read()
            resp.status = falcon.HTTP_200
        else:
            resp.text = "policy.html not found!"
            resp.status = falcon.HTTP_404

class FAQ:
    def on_get(self, req: Request, resp: Response):
        resp.content_type = "text/html; charset=utf-8"
        if os.path.exists("faq.html"):
            resp.text = open("faq.html", "r", encoding='utf-8').read()
            resp.status = falcon.HTTP_200
        else:
            resp.text = "faq.html not found!"
            resp.status = falcon.HTTP_404

# -------------------- API: POST /api/tpay/create -----------------------
class TpayCreate:
    def on_post(self, req: Request, resp: Response):
        try:
            body = req.media
            logging.info(f"[TpayCreate] BODY: {body}")

            amount_rub = float(body.get("amount", 0))
            amount_cop = int(amount_rub * 100)
            order_id = body.get("order_id", f"ord_{int(time.time())}")

            payment_payload = {
                "TerminalKey": TINKOFF_TERMINAL_KEY,
                "Amount": amount_cop,
                "OrderId": order_id,
                "Description": str(body.get("description", "Payment"))[:140],
            }
            if "email" in body:
                payment_payload["Email"] = body["email"]
            # Если комиссия передана, добавляем её во вложенный объект DATA (не учитывается при расчёте токена)
            if "commission" in body:
                payment_payload["DATA"] = {"Commission": body["commission"]}

            payment_payload["Token"] = make_tinkoff_token(payment_payload)
            url = "https://securepay.tinkoff.ru/v2/Init"
            r = requests.post(url, json=payment_payload, timeout=15)
            result = r.json()
            logging.info(f"[TpayCreate] /Init => {result}")

            if result.get("Success") and result.get("PaymentURL"):
                payment_url = result["PaymentURL"]
            else:
                resp.media = {"error": "Ошибка Tinkoff Init", "details": result}
                resp.status = falcon.HTTP_400
                return

            payment_id = result.get("PaymentId")
            if payment_id is not None:
                payment_id = str(payment_id)
            else:
                resp.media = {"error": "В ответе отсутствует PaymentId"}
                resp.status = falcon.HTTP_400
                return

            token_data = {"PaymentURL": payment_url, "PaymentId": payment_id, "OrderId": order_id}
            token = encode_token(token_data, TINKOFF_SECRET_KEY)

            resp.media = {"token": token, "payment_url": payment_url}
            resp.status = falcon.HTTP_200

        except Exception as e:
            logging.error(f"[TpayCreate] error: {e}")
            resp.media = {"error": str(e)}
            resp.status = falcon.HTTP_500

# -------------------- API: POST /api/tpay/status -----------------------
class TpayStatus:
    def on_post(self, req: Request, resp: Response):
        try:
            body = req.media
            # Если передан order_id, проверяем через CheckOrder
            if "order_id" in body:
                order_id = body.get("order_id")
                data_state = {
                    "TerminalKey": TINKOFF_TERMINAL_KEY,
                    "OrderId": order_id,
                }
                data_state["Token"] = make_tinkoff_token(data_state)
                url = "https://securepay.tinkoff.ru/v2/CheckOrder"
            elif "paymentId" in body:
                payment_id = body.get("paymentId")
                data_state = {
                    "TerminalKey": TINKOFF_TERMINAL_KEY,
                    "PaymentId": str(payment_id),
                }
                data_state["Token"] = make_tinkoff_token(data_state)
                url = "https://securepay.tinkoff.ru/v2/GetState"
            else:
                resp.media = {"error": "Не передан order_id или paymentId"}
                resp.status = falcon.HTTP_400
                return

            r = requests.post(url, json=data_state, timeout=15)
            rj = r.json()
            logging.info(f"[TpayStatus] response => {rj}")
            resp.media = rj
            resp.status = falcon.HTTP_200

        except Exception as e:
            logging.error(f"[TpayStatus] error: {e}")
            resp.media = {"error": str(e)}
            resp.status = falcon.HTTP_500

# -------------------- Endpoint: GET /pay/{token} -----------------------
class PaymentRedirect:
    def on_get(self, req: Request, resp: Response, token: str):
        try:
            token_data = decode_token(token, TINKOFF_SECRET_KEY)
            payment_url = token_data.get("PaymentURL")
            if not payment_url:
                resp.media = {"error": "В токене нет PaymentURL. Создайте новый платеж."}
                resp.status = falcon.HTTP_404
                return
            resp.set_header("Location", payment_url)
            resp.status = falcon.HTTP_302
        except Exception as e:
            logging.error(f"[PaymentRedirect] error: {e}")
            resp.media = {"error": str(e)}
            resp.status = falcon.HTTP_400

# -------------------- Endpoint для /pay без token -----------------------
class PaymentLanding:
    def on_get(self, req: Request, resp: Response):
        resp.media = {"message": "Для создания платежа используйте команду в боте."}
        resp.status = falcon.HTTP_200

app = falcon.App()

app.add_route('/static/{path}', StaticFolder())
app.add_route('/', MainPage())
app.add_route('/offer', Offer())
app.add_route('/policy', Policy())
app.add_route('/faq', FAQ())

app.add_route('/api/tpay/create', TpayCreate())
app.add_route('/api/tpay/status', TpayStatus())

app.add_route('/pay/{token}', PaymentRedirect())
app.add_route('/pay', PaymentLanding())
