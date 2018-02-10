#!/usr/bin/env python3

# Requirements
# tlp, tlp-rdw, python3-gi, notify-send

# Installing TLP:
# sudo add-apt-repository ppa:linrunner/tlp
# sudo apt update
# sudo apt install tlp tlp-rdw

# Configure TLP (optional): 
# http://askubuntu.com/questions/285434/is-there-a-power-saving-application-similar-to-jupiter

# Documentation of TLP: http://linrunner.de/en/tlp/docs/tlp-linux-advanced-power-management.html


from gi.repository import GObject as gobject
from gi import require_version

require_version('Gtk', '3.0')
require_version('AppIndicator3', '0.1')

from gi.repository import Gtk as gtk
from gi.repository import AppIndicator3 as appindicator
import subprocess
import time



def sendmessage(title, message, image):
  """ Send a notification message
  Args:
      title (str) : The title
      message (str) : The message
      image (str) : The image
  """
  if "None" in message:
      message = "No changes made."
      image = "/usr/share/icons/Humanity/status/48/dialog-info.svg"
  subprocess.call(['notify-send', '-i', image, title, message])

def start_AC(response):
  """ Apply power saving settings for AC power source. """
  command = "gksu tlp ac"
  process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=None, shell=True)
  output = str(process.communicate())[3:25]
  sendmessage("TLP Indicator",output, "/usr/share/icons/Humanity/status/48/gpm-ac-adapter.svg")

def start_BAT(response):
  """ Apply power saving settings for battery power source. """
  command = "gksu tlp bat"
  process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=None, shell=True)
  output = str(process.communicate())[3:30]
  sendmessage("TLP Indicator",output, "/usr/share/icons/Humanity/status/48/battery-low.svg")

def check(response):
  """ Show TLP stat output. """
  command = "tlp-stat -r"
  process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=None, shell=True)
  output = str(process.communicate())
  if output.find("power management = off") == -1:
    sendmessage("TLP Indicator","BAT Mode is on!", "/usr/share/icons/Humanity/status/48/dialog-info.svg")
  else:
    sendmessage("TLP Indicator","AC Mode is on!", "/usr/share/icons/Humanity/status/48/dialog-info.svg")

def quit(response):
  """ Quit TLP Indicator. """
  sendmessage("TLP Indicator","TLP Indicator quits. TLP itself is still running.", "/usr/share/icons/Humanity/status/48/gpm-ac-adapter.svg")
  time.sleep(1)
  raise SystemExit

if __name__ == "__main__":
  ind = appindicator.Indicator.new ("TLP-manager",
                              "battery-040-charging",
                              appindicator.IndicatorCategory.HARDWARE)
  ind.set_status (appindicator.IndicatorStatus.ACTIVE)

  # create a menu
  menu = gtk.Menu()

  # create items
  AC_item = gtk.MenuItem("AC-Mode")
  BAT_item = gtk.MenuItem("Battery Mode")
  check_item = gtk.MenuItem("Check")
  quit_item = gtk.MenuItem("Quit")

  # add items to the menu
  menu.append(AC_item)
  menu.append(BAT_item)
  menu.append(check_item)
  menu.append(quit_item)

  # attach function to items
  AC_item.connect_object("activate", start_AC, "AC MODE")
  BAT_item.connect_object("activate", start_BAT, "BAT MODE")
  check_item.connect_object("activate", check, "CHECK")
  quit_item.connect_object ("activate", quit, "QUIT")

  # show items
  AC_item.show()
  BAT_item.show()
  check_item.show()
  quit_item.show()

  ind.set_menu(menu)

  gtk.main()
