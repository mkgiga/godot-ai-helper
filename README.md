# Godot AI Helper

A simple Godot 4 editor plugin to quickly gather context about your project (scripts, scenes) for AI assistants

This plugin creates a tab in the right sidebar (where the inspector is) to easily add scripts and scene trees to a list of included resources. Once you're done, go to the Output tab and press Regenerate.

## Usage

1.  **Install & Enable:** Put `godot-ai-helper` in `addons/`, enable in `Project Settings -> Plugins`.
2.  **Find Dock:** Look for the "AI Helper" dock tab.
3.  **Add:** Open a script/scene, click "**Include Current Script**" or "**Include Current Scene Tree**" in the plugin's "Context" tab.
4.  **Copy:** Go to the "Output" tab, click "**Refresh Output**", then copy the generated text.

## Installation
Method **A**:
1. Install the addon using the AssetLib. Search for 'Godot AI Helper'

---

Method **B**:
	
1.  ```
	git clone https://github.com/mkgiga/godot-ai-helper
	```
2. Place the `godot-ai-helper` folder into your project's `addons/` directory.
3. Go to `Project -> Project Settings -> Plugins` and enable "AI Helper".