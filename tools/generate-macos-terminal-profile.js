ObjC.import("AppKit");
ObjC.import("Foundation");

function fail(message) {
    throw new Error(message);
}

function parseConfig(path) {
    const source = ObjC.unwrap(
        $.NSString.stringWithContentsOfFileEncodingError(
            path,
            $.NSUTF8StringEncoding,
            null
        )
    );
    if (source === undefined) {
        fail(`Cannot read Ghostty config: ${path}`);
    }

    const values = {};
    const palette = {};
    for (const rawLine of source.split("\n")) {
        const line = rawLine.trim();
        if (line === "" || line.startsWith("#")) {
            continue;
        }
        const separator = line.indexOf("=");
        if (separator === -1) {
            continue;
        }
        const key = line.slice(0, separator).trim();
        const value = line.slice(separator + 1).trim();
        if (key === "palette") {
            const paletteSeparator = value.indexOf("=");
            if (paletteSeparator === -1) {
                fail(`Invalid Ghostty palette row: ${line}`);
            }
            const index = value.slice(0, paletteSeparator).trim();
            palette[index] = value.slice(paletteSeparator + 1).trim();
        } else {
            values[key] = value;
        }
    }
    return { values, palette };
}

function requiredValue(config, key) {
    const value = config.values[key];
    if (value === undefined || value === "") {
        fail(`Ghostty config is missing ${key}`);
    }
    return value;
}

function integerValue(config, key) {
    const value = requiredValue(config, key);
    if (!/^[1-9][0-9]*$/.test(value)) {
        fail(`Ghostty ${key} must be a positive integer: ${value}`);
    }
    return Number(value);
}

function numberValue(config, key) {
    const value = requiredValue(config, key);
    const number = Number(value);
    if (!Number.isFinite(number) || number <= 0) {
        fail(`Ghostty ${key} must be positive: ${value}`);
    }
    return number;
}

function color(hex, alpha = 1) {
    if (!/^[0-9a-fA-F]{6}$/.test(hex)) {
        fail(`Terminal profile color must be six hexadecimal digits: ${hex}`);
    }
    const component = offset => parseInt(hex.slice(offset, offset + 2), 16) / 255;
    return $.NSColor.colorWithCalibratedRedGreenBlueAlpha(
        component(0),
        component(2),
        component(4),
        alpha
    );
}

function archive(value) {
    return $.NSKeyedArchiver.archivedDataWithRootObject(value);
}

function set(profile, key, value) {
    profile.setObjectForKey(value, key);
}

function buildProfile(config) {
    const fontFamily = requiredValue(config, "font-family");
    const fontSize = numberValue(config, "font-size");
    const font = $.NSFontManager.sharedFontManager.fontWithFamilyTraitsWeightSize(
        fontFamily,
        0,
        5,
        fontSize
    );
    if (!font) {
        fail(`Cannot resolve Terminal font family: ${fontFamily}`);
    }

    const profile = $.NSMutableDictionary.alloc.init;
    set(profile, "name", "SeaShells");
    set(profile, "type", "Window Settings");
    set(profile, "ProfileCurrentVersion", 2.09);
    set(profile, "Font", archive(font));
    set(profile, "FontAntialias", true);
    set(profile, "FontHeightSpacing", 1);
    set(profile, "FontWidthSpacing", 1);
    set(profile, "columnCount", integerValue(config, "window-width"));
    set(profile, "rowCount", integerValue(config, "window-height"));
    set(profile, "CursorType", 0);
    set(profile, "CursorBlink", true);
    set(profile, "DynamicANSIForegroundColors", false);
    set(profile, "BackgroundBlur", 0);
    set(profile, "BackgroundBlurInactive", 0);
    set(profile, "BackgroundSettingsForInactiveWindows", false);

    const backgroundOpacity = numberValue(config, "background-opacity");
    if (backgroundOpacity > 1) {
        fail(`Ghostty background-opacity must not exceed 1: ${backgroundOpacity}`);
    }
    set(profile, "BackgroundColor", archive(color(
        requiredValue(config, "background"),
        backgroundOpacity
    )));
    set(profile, "TextColor", archive(color(requiredValue(config, "foreground"))));
    set(profile, "TextBoldColor", archive(color(requiredValue(config, "foreground"))));
    set(profile, "CursorColor", archive(color(requiredValue(config, "cursor-color"))));
    set(profile, "SelectionColor", archive(color(requiredValue(config, "selection-background"))));
    set(profile, "SelectedTextColor", archive(color(requiredValue(config, "selection-foreground"))));

    const ansiKeys = [
        "ANSIBlackColor",
        "ANSIRedColor",
        "ANSIGreenColor",
        "ANSIYellowColor",
        "ANSIBlueColor",
        "ANSIMagentaColor",
        "ANSICyanColor",
        "ANSIWhiteColor",
        "ANSIBrightBlackColor",
        "ANSIBrightRedColor",
        "ANSIBrightGreenColor",
        "ANSIBrightYellowColor",
        "ANSIBrightBlueColor",
        "ANSIBrightMagentaColor",
        "ANSIBrightCyanColor",
        "ANSIBrightWhiteColor"
    ];
    for (let index = 0; index < ansiKeys.length; index += 1) {
        const value = config.palette[String(index)];
        if (value === undefined) {
            fail(`Ghostty config is missing palette index ${index}`);
        }
        set(profile, ansiKeys[index], archive(color(value)));
    }
    return profile;
}

function run(argv) {
    if (argv.length !== 1) {
        fail("Usage: osascript -l JavaScript tools/generate-macos-terminal-profile.js GHOSTTY_CONFIG");
    }
    const profile = buildProfile(parseConfig(argv[0]));
    const data = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
        profile,
        $.NSPropertyListXMLFormat_v1_0,
        0,
        null
    );
    if (!data) {
        fail("Cannot serialize the Terminal profile");
    }
    $.NSFileHandle.fileHandleWithStandardOutput.writeData(data);
}
