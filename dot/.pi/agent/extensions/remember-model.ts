import { getAgentDir, SettingsManager, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Interactive choices become startup defaults. Restoring history and automated
// runs must not replace the last explicit choice.
export default function (pi: ExtensionAPI) {
	pi.on("model_select", async (event, ctx) => {
		if (ctx.mode !== "tui" || event.source === "restore") return;

		// Pi's writer locks and merges only modified keys, preserving other settings.
		const settings = SettingsManager.create(ctx.cwd, getAgentDir());
		settings.setDefaultModelAndProvider(event.model.provider, event.model.id);
		await settings.flush();
		const failure = settings.drainErrors()[0];
		if (failure) throw failure.error;
	});
}
