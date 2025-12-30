import Cocoa

/// A custom table row view that provides hover and selection effects
public class HoverTableRowView: NSTableRowView {
    private var isHovered = false

    /// Draws the selection highlight with rounded corners - subtle like Raycast
    public override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            let selectionRect = NSRect(x: 8, y: 2, width: self.bounds.width - 16, height: self.bounds.height - 4)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            // Subtle highlight - slightly darker/lighter than background
            NSColor.labelColor.withAlphaComponent(0.15).setFill()
            path.fill()
        }
    }

    /// Draws the background including hover state
    public override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if isHovered && !isSelected {
            let hoverRect = NSRect(x: 8, y: 2, width: self.bounds.width - 16, height: self.bounds.height - 4)
            let path = NSBezierPath(roundedRect: hoverRect, xRadius: 6, yRadius: 6)
            NSColor.labelColor.withAlphaComponent(0.05).setFill()
            path.fill()
        }
    }

    /// Updates the tracking area for mouse hover effects
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    /// Handles mouse enter events to show hover effect
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        needsDisplay = true
    }

    /// Handles mouse exit events to remove hover effect
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        needsDisplay = true
    }
}
