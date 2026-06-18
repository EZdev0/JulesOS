#!/usr/bin/env python3
"""
JulesOS Legacy Translator GUI
A Wayland GTK3 graphical interface for Box86/Box64/Wine binary translation.
"""
import os
import subprocess
import threading
import time

# pylint: disable=import-error,no-name-in-module
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Pango
# pylint: enable=import-error,no-name-in-module

class TranslatorGUI(Gtk.Window):
    """Main window class for the Translator GUI."""
    def __init__(self):
        super().__init__(title="JulesOS Legacy Translator")
        self.set_default_size(800, 600)
        self.set_border_width(10)
        
        # Setup Layout
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(vbox)
        
        # Header
        header = Gtk.Label()
        header.set_markup("<big><b>JulesOS Advanced Binary Translation</b></big>")
        vbox.pack_start(header, False, False, 0)
        
        # File Selection
        hbox_file = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        vbox.pack_start(hbox_file, False, False, 0)
        
        self.file_entry = Gtk.Entry()
        self.file_entry.set_placeholder_text("Select legacy binary (.exe or 32-bit ELF)...")
        self.file_entry.set_hexpand(True)
        hbox_file.pack_start(self.file_entry, True, True, 0)
        
        btn_browse = Gtk.Button(label="Browse")
        btn_browse.connect("clicked", self.on_browse_clicked)
        hbox_file.pack_start(btn_browse, False, False, 0)
        
        # Engine Selection
        hbox_engine = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        vbox.pack_start(hbox_engine, False, False, 0)
        
        hbox_engine.pack_start(Gtk.Label(label="Translation Engine:"), False, False, 0)
        
        self.engine_combo = Gtk.ComboBoxText()
        self.engine_combo.append_text("Auto-Detect")
        self.engine_combo.append_text("Box86 (32-bit x86 ELF)")
        self.engine_combo.append_text("Box64 (64-bit x86_64 ELF)")
        self.engine_combo.append_text("Wine (Windows .exe)")
        self.engine_combo.set_active(0)
        hbox_engine.pack_start(self.engine_combo, True, True, 0)
        
        # Run Button
        self.btn_run = Gtk.Button(label="⚡ TRANSLATE & RUN")
        self.btn_run.connect("clicked", self.on_run_clicked)
        vbox.pack_start(self.btn_run, False, False, 0)
        
        # Logging Area
        log_label = Gtk.Label(label="Live Translation & Kernel Syscall Log:")
        log_label.set_halign(Gtk.Align.START)
        vbox.pack_start(log_label, False, False, 0)
        
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        vbox.pack_start(scrolled, True, True, 0)
        
        self.log_textview = Gtk.TextView()
        self.log_textview.set_editable(False)
        self.log_textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.log_textview.modify_font(Pango.FontDescription('Monospace 10'))
        
        # CSS for terminal look
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"textview { background-color: #1e1e1e; color: #00ff00; }")
        context = self.log_textview.get_style_context()
        context.add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        
        scrolled.add(self.log_textview)
        
        self.log_buffer = self.log_textview.get_buffer()
        self.process = None
        
        # Ensure log directory exists
        os.makedirs("/var/log/jules-translator", exist_ok=True)
        self.log_file = "/var/log/jules-translator/translation.log"
        self.log(f"[{time.strftime('%H:%M:%S')}] JulesOS Legacy Translator Initialized.")
        self.log(f"[{time.strftime('%H:%M:%S')}] Awaiting legacy binary input...")

    def log(self, message):
        """Append message to GUI and log file safely from any thread."""
        def append_text():
            end_iter = self.log_buffer.get_end_iter()
            self.log_buffer.insert(end_iter, message + "\n")
            
            # Scroll to bottom
            mark = self.log_buffer.create_mark(None, self.log_buffer.get_end_iter(), False)
            self.log_textview.scroll_to_mark(mark, 0.0, True, 0.0, 1.0)
            
            # Write to file
            try:
                with open(self.log_file, "a", encoding="utf-8") as f:
                    f.write(message + "\n")
            except OSError:
                pass

        GLib.idle_add(append_text)

    def on_browse_clicked(self, _widget):
        """Handle browse button click to open file selection dialog."""
        dialog = Gtk.FileChooserDialog(
            title="Please choose a legacy binary", parent=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            self.file_entry.set_text(dialog.get_filename())
        dialog.destroy()

    def on_run_clicked(self, _widget):
        """Handle run button click to execute translation engine."""
        file_path = self.file_entry.get_text()
        if not file_path or not os.path.exists(file_path):
            self.log("❌ ERROR: File not found or empty path.")
            return
            
        engine_idx = self.engine_combo.get_active()
        engine_name = self.engine_combo.get_active_text()
        
        self.log("=" * 60)
        self.log("⚡ INITIATING BINARY TRANSLATION...")
        self.log(f"Target File: {file_path}")
        self.log(f"Engine Selected: {engine_name}")
        self.log("=" * 60)
        
        # Determine execution command
        cmd = []
        if engine_idx == 1:
            cmd = ["box86", file_path]
        elif engine_idx == 2:
            cmd = ["box64", file_path]
        elif engine_idx == 3:
            cmd = ["wine", file_path]
        else:
            # Auto-detect logic
            if file_path.lower().endswith(".exe"):
                cmd = ["wine", file_path]
                self.log("Auto-detected Windows executable -> Using Wine")
            else:
                # Default to box86 for unknown ELF (assuming 32-bit legacy)
                cmd = ["box86", file_path]
                self.log("Auto-detected ELF -> Using Box86")
                
        # Disable button during run
        self.btn_run.set_sensitive(False)
        
        # Start execution in background thread
        thread = threading.Thread(target=self.execute_translation, args=(cmd,))
        thread.daemon = True
        thread.start()

    def execute_translation(self, cmd):
        """Execute the selected translation engine in a separate thread."""
        self.log("[KERNEL] Mapping SYS_CALL translation tables...")
        self.log(f"[KERNEL] Launching emulator wrapper: {' '.join(cmd)}")
        
        try:
            # Run the process and capture output in real-time
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            for line in self.process.stdout:
                self.log(f"[TRANSLATOR] {line.strip()}")
                
            self.process.wait()
            rc = self.process.returncode
            
            if rc == 0:
                self.log(f"✅ PROCESS COMPLETED SUCCESSFULLY (Exit Code: {rc})")
            else:
                self.log(f"⚠️ PROCESS EXITED WITH CODE: {rc}")

        except FileNotFoundError:
            self.log(f"❌ ERROR: Translation engine '{cmd[0]}' not installed.")
        except OSError as e:
            self.log(f"❌ CRITICAL ERROR: {str(e)}")

        finally:
            # Re-enable button
            GLib.idle_add(self.btn_run.set_sensitive, True)

if __name__ == "__main__":
    win = TranslatorGUI()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
