import logging
import multiprocessing
from gunicorn.app.wsgiapp import WSGIApplication
import server  # файл server.py должен содержать ваше Falcon-приложение как объект "app"

logging.basicConfig(level='INFO')


class StandaloneApplication(WSGIApplication):
    def __init__(self, app_uri, options=None):
        self.options = options or {}
        self.app_uri = app_uri
        super().__init__()

    def load_config(self):
        config = {
            key: value
            for key, value in self.options.items()
            if key in self.cfg.settings and value is not None
        }
        for key, value in config.items():
            self.cfg.set(key.lower(), value)


def run():
    # Настройки Gunicorn для Docker
    options = {
        "bind": "0.0.0.0:8000",  # Изменили порт на 8000
        "workers": (multiprocessing.cpu_count() * 2) + 1,
        "timeout": 120,
        "worker_class": "sync",
        "max_requests": 1000,
        "max_requests_jitter": 50,
        "preload_app": True,
        "keep_alive": 5,
    }
    StandaloneApplication("server:app", options).run()


if __name__ == '__main__':
    run()
