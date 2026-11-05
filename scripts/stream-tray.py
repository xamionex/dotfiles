#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys

from PyQt5.QtCore import QTimer, Qt, QUrl
from PyQt5.QtGui import QColor, QDesktopServices, QIcon, QPainter, QPen, QPixmap
from PyQt5.QtWidgets import QApplication, QMenu, QSystemTrayIcon

POLL_INTERVAL_MS = 2000


def pid_alive(pid):
    if pid <= 0:
        return False

    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True

    return True


class StreamTray:
    def __init__(self, args):
        self.args = args
        self.app = QApplication([sys.argv[0]])
        self.app.setQuitOnLastWindowClosed(False)
        self.app.aboutToQuit.connect(self.remove_pid_file)

        self.icon = None
        self.menu = None
        self.stopping = False

        if not QSystemTrayIcon.isSystemTrayAvailable():
            print("system tray is not available", file=sys.stderr, flush=True)
            sys.exit(1)

        self.menu = self.build_menu()
        self.icon = QSystemTrayIcon(self.build_icon(), self.app)
        self.icon.setToolTip(self.build_tooltip())
        self.icon.setContextMenu(self.menu)
        self.icon.activated.connect(self.on_activated)
        self.icon.show()

        self.timer = QTimer(self.app)
        self.timer.timeout.connect(self.poll)
        self.timer.start(POLL_INTERVAL_MS)

    def build_icon(self):
        size = 64
        pixmap = QPixmap(size, size)
        pixmap.fill(Qt.transparent)

        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setBrush(QColor("#e01b24"))
        painter.setPen(QPen(QColor("#8e1519"), 3))
        painter.drawEllipse(8, 8, size - 16, size - 16)
        painter.end()

        return QIcon(pixmap)

    def build_tooltip(self):
        lines = [
            f"Streaming: {self.args.key}",
            self.args.watch_url,
        ]

        if self.args.teamspeak:
            lines.append("TeamSpeak mode")

        return "\n".join(lines)

    def build_menu(self):
        menu = QMenu()

        title = menu.addAction(f"Streaming: {self.args.key}")
        title.setEnabled(False)

        if self.args.teamspeak:
            mode = menu.addAction("TeamSpeak mode: on")
            mode.setEnabled(False)

        menu.addSeparator()

        open_action = menu.addAction("Open stream page")
        open_action.triggered.connect(self.open_stream)

        stop_action = menu.addAction("Stop stream")
        stop_action.triggered.connect(self.stop_stream)

        menu.addSeparator()

        quit_action = menu.addAction("Quit indicator")
        quit_action.triggered.connect(self.app.quit)

        return menu

    def open_stream(self):
        QDesktopServices.openUrl(QUrl(self.args.watch_url))

    def on_activated(self, reason):
        if reason == QSystemTrayIcon.Trigger:
            self.open_stream()

    def poll(self):
        if self.stopping:
            return

        if not pid_alive(self.args.pid):
            self.app.quit()

    def stop_stream(self):
        if self.stopping:
            return

        self.stopping = True
        subprocess.Popen(
            [self.args.script, "stop"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        self.app.quit()

    def remove_pid_file(self):
        try:
            with open(self.args.tray_pid_file, "r", encoding="utf-8") as handle:
                pid = handle.read().strip()
        except OSError:
            return

        if pid != str(os.getpid()):
            return

        try:
            os.unlink(self.args.tray_pid_file)
        except OSError:
            pass

    def run(self):
        self.app.exec_()


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--watch-url", required=True)
    parser.add_argument("--script", required=True)
    parser.add_argument("--tray-pid-file", required=True)
    parser.add_argument("--teamspeak", action="store_true")
    return parser.parse_args()


def main():
    StreamTray(parse_args()).run()


if __name__ == "__main__":
    main()
