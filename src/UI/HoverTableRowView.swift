import Cocoa

/// A custom table row view that provides hover and selection effects
public class HoverTableRowView: NSTableRowView {
    /// Draws the selection highlight with rounded corners
    /// - Parameter dirtyRect: The area that needs to be redrawn
    public override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            let selectionRect = NSRect(x: 2, y: 2, width: self.bounds.width - 4, height: self.bounds.height - 4)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            NSColor.white.withAlphaComponent(0.1).setFill()
            path.fill()
        }
    }

    /// Updates the tracking area for mouse hover effects
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.removeTrackingArea(self.trackingAreas.first ?? NSTrackingArea())
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil))
    }

    /// Handles mouse enter events to show hover effect
    /// - Parameter event: The mouse event
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected {
            let hoverRect = NSRect(x: 2, y: 2, width: self.bounds.width - 4, height: self.bounds.height - 4)
            let path = NSBezierPath(roundedRect: hoverRect, xRadius: 6, yRadius: 6)
            NSColor.white.withAlphaComponent(0.05).setFill()
            path.fill()
        }
        self.needsDisplay = true
    }

    /// Handles mouse exit events to remove hover effect
    /// - Parameter event: The mouse event
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.needsDisplay = true
    }
}
