import Carbon

final class HotkeyManager {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  var onTrigger: (() -> Void)?

  func registerNewMemoShortcut() {
    unregister()

    var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let callback: EventHandlerUPP = { _, event, userData in
      guard let userData else {
        return noErr
      }

      let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
      var hotKeyID = EventHotKeyID()
      let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
      )

      guard status == noErr, hotKeyID.id == 1 else {
        return noErr
      }

      manager.onTrigger?()
      return noErr
    }

    InstallEventHandler(
      GetApplicationEventTarget(),
      callback,
      1,
      &eventSpec,
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
      &eventHandlerRef
    )

    let hotKeyID = EventHotKeyID(signature: OSType(0x53545042), id: 1)
    RegisterEventHotKey(
      UInt32(kVK_Return),
      UInt32(cmdKey | optionKey),
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
  }

  func unregister() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }

    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }
  }

  deinit {
    unregister()
  }
}
