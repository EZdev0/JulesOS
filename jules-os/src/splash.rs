use std::io::{self, Write};
use std::thread;
use std::time::Duration;
use crate::colors::{CYAN, RESET, BOLD};

/// Jules AI Agent Octopus - Clean ASCII art splash logo.
/// Designed for dark terminal backgrounds (init/TTY).
pub const SPLASH_LOGO: &str = concat!(
    "\x1b[38;2;80;200;255m",
    "                        ___\n",
    "                     .-'   `'.\n",
    "                    /         \\\n",
    "                   |           |\n",
    "                   |  \x1b[38;2;255;255;255m O   O \x1b[38;2;80;200;255m  |\n",
    "                    \\  \\___/  /\n",
    "                     '._____.'  \x1b[38;2;100;220;255mJules\x1b[38;2;80;200;255m\n",
    "                    /|       |\\\n",
    "                   / |       | \\\n",
    "                  /  |       |  \\\n",
    "                 /  /|       |\\  \\\n",
    "                (  / |       | \\  )\n",
    "                 \\/ /         \\ \\/\n",
    "                   /    / \\    \\\n",
    "                  /    /   \\    \\\n",
    "                 (    /     \\    )\n",
    "                  \\  /       \\  /\n",
    "                   \\/         \\/\n",
    "\x1b[0m",
);

pub fn run_splash() {
    print!("\x1b[2J\x1b[1;1H"); // Clear screen
    let _ = io::stdout().flush();

    println!("\n\n");

    // Print the Jules Octopus Logo line by line with fade-in effect
    for line in SPLASH_LOGO.lines() {
        println!("{line}");
        thread::sleep(Duration::from_millis(30));
    }

    println!();

    // Animate the loading spinner
    let frames = [
        "\x1b[38;2;80;200;255m[ \u{25CF}     ] ",
        "\x1b[38;2;80;200;255m[  \u{25CF}    ] ",
        "\x1b[38;2;80;200;255m[   \u{25CF}   ] ",
        "\x1b[38;2;80;200;255m[    \u{25CF}  ] ",
        "\x1b[38;2;80;200;255m[     \u{25CF} ] ",
        "\x1b[38;2;80;200;255m[    \u{25CF}  ] ",
        "\x1b[38;2;80;200;255m[   \u{25CF}   ] ",
        "\x1b[38;2;80;200;255m[  \u{25CF}    ] ",
    ];
    let mut i = 0;

    print!("\x1b[?25l"); // Hide cursor
    for _ in 0..32 {
        print!("\r                    {}{BOLD} Booting Jules AI Agent...{RESET}", frames[i]);
        let _ = io::stdout().flush();
        i = (i + 1) % frames.len();
        thread::sleep(Duration::from_millis(120));
    }
    print!("\x1b[?25h"); // Show cursor
    println!("\n");
}
