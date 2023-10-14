//
//  Window.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 10/10/2023.
//

import Foundation
import RegexBuilder

struct ScriptingBridgeError: Error {

}

private let _unsafe = Regex {
  CharacterClass(
    .anyOf("@%+=:,./-"),
    .word
  )
  .inverted
}

/// Return a shell-escaped version of the string
private func quote(arg: String) -> String {
  guard !arg.isEmpty else { return "''" }

  if arg.firstMatch(of: _unsafe) == nil {
    return arg
  }

  // use single quotes, and put single quotes into double quotes
  // the string $'b is then quoted as '$'"'"'b'
  return "'" + arg.replacing("'", with: #"'"'"'"#) + "'"

}

extension Terminal {

  struct Tab {

    let tab: TerminalTab
    let window: TerminalWindow
    let terminal: TerminalApplication

    let tabIdx: Int
    let windowId: CGWindowID

    func run(args: [String]) throws {
      let script = args.map(quote(arg:)).joined(separator: " ")
      guard terminal.doScript(script, in: tab) == tab else {
        throw ScriptingBridgeError()
      }
    }

    // MARK: Window Management
    func bounds() -> CGRect {
      return window.bounds
    }

    func move(x dx: CGFloat, y dy: CGFloat) {
      let orig = window.origin
      window.origin = NSPoint(x: orig.x + 5 * dx, y: orig.y + 5 * dy)
    }

    func grow(width dw: CGFloat, height dh: CGFloat) {
      let size = window.size
      window.size = CGPoint(x: size.x + 5 * dw, y: size.y + 5 * dh)
    }

    func hide() {
      window.visible = false
    }

    func minimise() {
      window.miniaturized = true
    }

    func close() {
      window.closeSaving(TerminalSaveOptionsNo, savingIn: nil)
    }

    var space: Int32 {
      get {
        var ws: CGSWorkspace = 0
        let error: CGError = CGSGetWindowWorkspace(CGSDefaultConnection(), windowId, &ws)
        guard error == .success else {
          logger.warning("error while querying window space: \(error.rawValue)")
          return -1
        }
        return ws
      }
      nonmutating set {
        var wids = windowId
        let error = CGSMoveWorkspaceWindowList(CGSDefaultConnection(), &wids, 1, newValue)
        if error != .success {
          logger.warning("error while setting window space: \(error.rawValue)")
        }
      }
    }

    func setProfile(_ profile: String) -> Bool {
      guard let settings = terminal.settingsSets().object(withName: profile) as? TerminalSettingsSet else {
        // should never fails as it only create an ObjectDescriptor
        logger.warning("failed to create settings set \(profile)")
        return false
      }
      tab.currentSettings = settings
      return tab.currentSettings.name == profile
    }

    // var uid: String { "\(window.id),\(id)" }

    /*
     sub set_bg_color {
         my ($obj, $bg_color) = @_;
         $obj->tabobj->setBackgroundColor_($obj->make_NSColor($bg_color));
     }

     sub set_fg_color {
         my ($obj, $fg_color) = @_;
         $obj->tabobj->setNormalTextColor_($obj->make_NSColor($fg_color));
     }

     sub store_bg_color {
         my ($obj, $bg) = @_;
         *$obj->{'stored_bg_color'} = $obj->tabobj->backgroundColor();
     }

     sub store_fg_color {
         my ($obj, $fg) = @_;
         *$obj->{'stored_fg_color'} = $obj->tabobj->normalTextColor();
     }

     sub fetch_bg_color {
         my ($obj) = @_;
         return *$obj->{'stored_bg_color'} || '';
     }

     sub fetch_fg_color {
         my ($obj) = @_;
         return *$obj->{'stored_fg_color'} || '';
     }

     sub set_settings_set {
         my ($obj,$want) = @_;
         my $sets = $terminal->settingsSets;
         for (my $i=0; $i<$sets->count; $i++) {
             my $set = $sets->objectAtIndex_($i);
             if ($set->name->UTF8String eq $want) {
                 $obj->tabobj->setCurrentSettings_($set);
                 return 1;
             }
         }
         return;
     }
     */
  }
}


extension Terminal.Tab {

  static func open() throws -> Self {
    guard let bridge = TerminalApplication(bundleIdentifier: TerminalBundleId) else {
      throw ScriptingBridgeError()
    }

    guard let tab = bridge.doScript("", in: 0) else {
      throw ScriptingBridgeError()
    }

    // Get the window IDs from the Apple Event itself
    // The Tab Specifier looks like this:
    // 'obj '{
    //   'want':'ttab', 'form':'indx', 'seld':1, 'from':'obj '{
    //      'want':'cwin', 'form':'ID  ', 'seld':23600, 'from':[0x0,f0ef0e "Terminal"]
    //    }
    //  }
    guard let specifier = tab.qualifiedSpecifier(),
          let tabIdx = specifier.forKeyword(kSeldProperty)?.int32Value,
          // Get the 'from' property which is a Window object specifier
          let windowSpec = specifier.forKeyword(kFromProperty),
          // Get the specifier key which is the window 'ID  '
          let windowId = windowSpec.forKeyword(kSeldProperty),
          // And finally, create a TabWindow representing the tab's window.
          let window = bridge.windows().object(withID: windowId.int32Value) as? TerminalWindow
    else {
      throw ScriptingBridgeError()
    }

    return Terminal.Tab(tab: tab, 
                        window: window,
                        terminal: bridge,
                        tabIdx: Int(tabIdx),
                        windowId: CGWindowID(windowId.int32Value))
  }
}

struct Screen {
  // my ($cur_bounds, $max_bounds);
  /*
   sub screen_bounds {
       my ($obj) = @_;

       my ($x,$y,$w,$h);
       if ($cur_bounds) {
           return $cur_bounds;
       } elsif ($config->screen_bounds) {
           ($x,$y,$w,$h) = @{$config->screen_bounds};
       } else {
           my $scr = $config->screen;
           ($x,$y,$w,$h) = @{physical_screen_bounds($scr)};
       }
       $max_bounds = [ $x, $y, $w, $h ];
       return $cur_bounds = [ $x, $y, $w, $h ];
   }

   sub physical_screen_bounds {
       my ($scr) = @_;

       $scr ||= 1;
       $scr =~ /^(\d+)(?:-(\d+))?$/ || die "Screen must be a number (e.g. 1) or a range (e.g. 1-2)";
       my ($s1, $s2) = ($1,$2);

       my $displays =  NSScreen->screens()->count;
       die "No such screen [$s1], screen must be $displays or less"
           if $s1 > $displays;

       my $frame1 = NSScreen->screens->objectAtIndex_($s1-1)->visibleFrame;
       my $scr1   = [ObjCStruct::NSRect->unpack($frame1)];

       if (defined $s2) {
           # If it's a screen range - try to find a rectangle that
           # fits neatly across the screens

           die "No such screen [$s2], screen must be $displays or less"
               if $s2 > $displays;

           my $frame2 = NSScreen->screens->objectAtIndex_($s2-1)->visibleFrame;
           my $scr2   = [ObjCStruct::NSRect->unpack($frame2)];

           my $out  = [];

           if ($scr2->[0] >= ($scr1->[0]+$scr1->[2])) {
               # Left of scr2, is to right of right of scr1
               $out->[0] = $scr1->[0];
               $out->[2] = ($scr2->[0] + $scr2->[2]) - $scr1->[0];
           } elsif ($scr1->[0] >= ($scr2->[0]+$scr2->[2])) {
               # Left of scr1, is to right of right of scr2
               $out->[0] = $scr2->[0];
               $out->[2] = ($scr1->[0] + $scr1->[2]) - $scr2->[0];
           } else {
               $out->[0] = max($scr1->[0], $scr2->[0]);
               $out->[2] = min($scr1->[2], $scr2->[2]);
           }

           if ($scr2->[1] >= ($scr1->[1]+$scr1->[3])) {
               # Bottom of scr2, is above top of scr1
               $out->[1] = $scr1->[1];
               $out->[3] = ($scr2->[1] + $scr2->[3]) - $scr1->[1];
           } elsif ($scr1->[1] >= ($scr2->[1]+$scr2->[3])) {
               # Bottom of scr1, is above top of scr2
               $out->[1] = $scr2->[1];
               $out->[3] = ($scr1->[1] + $scr1->[3]) - $scr2->[1];
           } else {
               $out->[1] = max($scr1->[1], $scr2->[1]);
               $out->[3] = min($scr1->[3], $scr2->[3]);
           }

           return $out;

       } else {

           return $scr1;

       }
   }

   sub reset_bounds {
       $cur_bounds = [ @$max_bounds ];
   }

   sub max_physical_bounds {
       $cur_bounds = physical_screen_bounds($config->screen);
   }
   */
}
