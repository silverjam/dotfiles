#!/usr/bin/env python

#Install TLP first!
#sudo add-apt-repository ppa:linrunner/tlp
#sudo apt-get update
#sudo apt-get install tlp tlp-rdw

#Configure TLP (optional): http://askubuntu.com/questions/285434/is-there-a-power-saving-application-similar-to-jupiter

#Documentation of TLP: http://linrunner.de/en/tlp/docs/tlp-linux-advanced-power-management.html

import gobject
import gtk
import appindicator
import subprocess
import pynotify
import time

# code necessary to use pynotify:

def sendmessage(title, message, image):
  pynotify.init("TLP Indicator")
  notice = pynotify.Notification(title, message, image)
  notice.show()
  time.sleep(1)
  notice.update(title, message, image)
  notice.show()
  return

# define functions

def start_AC(response):
  command = "gksu tlp ac"
  process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=None, shell=True)
  output = str(process.communicate())[2:25]
  sendmessage("TLP Indicator",output, "/usr/share/icons/Humanity/status/48/gpm-ac-adapter.svg")

def start_BAT(response):
  command = "gksu tlp bat"
  process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=None, shell=True)
  output = str(process.communicate())[2:30]
  sendmessage("TLP Indicator",output, "/usr/share/icons/Humanity/status/48/battery-low.svg")

def check(response):
  command = "tlp-stat -r"
  process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=None, shell=True)
  output = str(process.communicate())
  if output.find("power management = off") == -1:
    sendmessage("TLP Indicator","BAT Mode is on!", "/usr/share/icons/Humanity/status/48/dialog-info.svg")
  else:
    sendmessage("TLP Indicator","AC Mode is on!", "/usr/share/icons/Humanity/status/48/dialog-info.svg")

def quit(response):
  sendmessage("TLP Indicator","TLP Indicator quits. TLP itself is still running.", "/usr/share/icons/Humanity/status/48/gpm-ac-adapter.svg")
  time.sleep(1)
  raise SystemExit

if __name__ == "__main__":
  ind = appindicator.Indicator ("TLP-manager",
                              "battery-040-charging",
                              appindicator.CATEGORY_HARDWARE)
  ind.set_status (appindicator.STATUS_ACTIVE)
 
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
