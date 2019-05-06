const config = require("./config");
const THREE_SECONDS_IN_MS = 3000;
const scenarios = [];
const viewports = [];

config.relativeUrls.map(relativeUrl => {
	scenarios.push({
		label: relativeUrl,
		url: `${config.baseUrl}${relativeUrl}`,
		delay: THREE_SECONDS_IN_MS,
		requireSameDimensions: false,
	});
});

config.viewports.map(viewport => {
	if (viewport === "phone") {
		pushViewport(viewport, 320, 480);
	}
	if (viewport === "tablet") {
		pushViewport(viewport, 1024, 768);
	}
	if (viewport === "desktop") {
		pushViewport(viewport, 1280, 1024);
	}
});

function pushViewport(viewport, width, height) {
	viewports.push({
		name: viewport,
		width,
		height,
	});
}

module.exports = {
	id: config.projectId,
	viewports,
	scenarios,
	paths: {
		bitmaps_reference: "test/backstop_data/bitmaps_reference",
		bitmaps_test: "test/backstop_data/bitmaps_test",
		html_report: "test/backstop_data/html_report"
	},
	report: ["browser"],
	engine: "puppeteer",
	engineOptions: {
		args: ["--no-sandbox"]
	},
	asyncCaptureLimit: 5,
	asyncCompareLimit: 50,
};
