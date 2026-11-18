package zombie.ui;

/** Tool-only package bridge for UIManager frame reset during headless UI preview. */
public final class PreviewFrame {
    private PreviewFrame() {}

    public static void resetStencilDepth() {
        UIElement.stencilLevel = 0;
    }

    public static void flushPendingUI() {
        UIManager.getUI().removeAll(UIManager.toRemove);
        UIManager.toRemove.clear();
        UIManager.getUI().addAll(UIManager.toAdd);
        UIManager.toAdd.clear();
    }
}
