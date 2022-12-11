FROM debian:bullseye-slim

ARG USERNAME=app
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # デバッグ用に sudo をインストール
    && apt-get update && apt-get install -y  --no-install-recommends \
    sudo=1.9* \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# デバッグ用
RUN apt-get update && apt-get install -y --no-install-recommends \
  # ps コマンドを使いたい。
  procps \
  vim \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
  supervisor=4.* \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
# ログファイル出力権限に関するエラーへの対処
# ```bash
# app@8adb871c70ca:/$ supervisord
# Traceback (most recent call last):
#   File "/usr/bin/supervisord", line 33, in <module>
#     sys.exit(load_entry_point('supervisor==4.2.2', 'console_scripts', 'supervisord')())
#   File "/usr/lib/python3/dist-packages/supervisor/supervisord.py", line 359, in main
#     go(options)
#   File "/usr/lib/python3/dist-packages/supervisor/supervisord.py", line 369, in go
#     d.main()
#   File "/usr/lib/python3/dist-packages/supervisor/supervisord.py", line 72, in main
#     self.options.make_logger()
#   File "/usr/lib/python3/dist-packages/supervisor/options.py", line 1494, in make_logger
#     loggers.handle_file(
#   File "/usr/lib/python3/dist-packages/supervisor/loggers.py", line 419, in handle_file
#     handler = RotatingFileHandler(filename, 'a', maxbytes, backups)
#   File "/usr/lib/python3/dist-packages/supervisor/loggers.py", line 213, in __init__
#     FileHandler.__init__(self, filename, mode)
#   File "/usr/lib/python3/dist-packages/supervisor/loggers.py", line 160, in __init__
#     self.stream = open(filename, mode)
# PermissionError: [Errno 13] Permission denied: '/var/log/supervisor/supervisord.log'
# app@8adb871c70ca:/$ 
# ```
RUN chown -R ${USERNAME}:${USERNAME} /var/log/supervisor/
# ソケットに関するエラーへの対処
# ```bash
# app@7f2dd72b1d50:/$ supervisord 
# Error: Cannot open an HTTP server: socket.error reported errno.EACCES (13)
# For help, use /usr/bin/supervisord -h
# app@7f2dd72b1d50:/$ 
# ```
RUN cp --archive /etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf.org \
  && sed -ri -e "s!/var/run/supervisor.sock!/home/${USERNAME}/var/run/supervisor.sock!g" /etc/supervisor/supervisord.conf \
  && mkdir -p /home/${USERNAME}/var/run/ \
  && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/
# Supervisor により管理するプログラム追加
COPY ./etc/supervisor/conf.d /etc/supervisor/conf.d

USER $USERNAME
