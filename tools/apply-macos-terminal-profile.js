ObjC.import("AppKit");
ObjC.import("Foundation");
ObjC.import("stdlib");

const terminalBundleID = "com.apple.Terminal";

function fail(message) {
    throw new Error(message);
}

function mutableDictionary(value, message) {
    if (!value) {
        return $.NSMutableDictionary.alloc.init;
    }
    try {
        return $.NSMutableDictionary.dictionaryWithDictionary(value);
    } catch (error) {
        fail(message);
    }
}

function parseArguments(argv) {
    const options = { profile: null, preferencesFile: null };
    for (let index = 0; index < argv.length; index += 1) {
        switch (argv[index]) {
        case "--":
            break;
        case "--profile":
            index += 1;
            if (index >= argv.length) {
                fail("--profile requires a path");
            }
            options.profile = argv[index];
            break;
        case "--preferences-file":
            index += 1;
            if (index >= argv.length) {
                fail("--preferences-file requires a path");
            }
            options.preferencesFile = argv[index];
            break;
        default:
            fail(`Unknown argument: ${argv[index]}`);
        }
    }
    if (!options.profile) {
        fail("--profile is required");
    }
    return options;
}

function readPlist(path) {
    const data = $.NSData.dataWithContentsOfFile(path);
    if (!data) {
        fail(`Cannot read property list: ${path}`);
    }
    const plist = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(
        data,
        $.NSPropertyListMutableContainersAndLeaves,
        null,
        null
    );
    return mutableDictionary(plist, `Property list root must be a dictionary: ${path}`);
}

function validateProfile(profile) {
    const name = ObjC.unwrap(profile.objectForKey("name"));
    const type = ObjC.unwrap(profile.objectForKey("type"));
    if (name !== "SeaShells" || type !== "Window Settings") {
        fail("Managed Terminal profile must be named SeaShells and use type Window Settings");
    }
    const requiredKeys = [
        "Font", "BackgroundColor", "TextColor", "CursorColor",
        "SelectionColor", "SelectedTextColor", "ANSIBlackColor",
        "ANSIRedColor", "ANSIGreenColor", "ANSIYellowColor",
        "ANSIBlueColor", "ANSIMagentaColor", "ANSICyanColor",
        "ANSIWhiteColor", "ANSIBrightBlackColor", "ANSIBrightRedColor",
        "ANSIBrightGreenColor", "ANSIBrightYellowColor",
        "ANSIBrightBlueColor", "ANSIBrightMagentaColor",
        "ANSIBrightCyanColor", "ANSIBrightWhiteColor"
    ];
    for (const key of requiredKeys) {
        if (!profile.objectForKey(key)) {
            fail(`Managed Terminal profile is missing ${key}`);
        }
    }
    return name;
}

function terminalIsRunning() {
    return $.NSRunningApplication.runningApplicationsWithBundleIdentifier(terminalBundleID).count > 0;
}

function reconcileDomain(domain, profile, profileName) {
    const result = mutableDictionary(
        domain,
        "Terminal preference domain must be a dictionary"
    );
    const settings = mutableDictionary(
        result.objectForKey("Window Settings"),
        "Terminal preference 'Window Settings' must be a dictionary"
    );
    const managedProfile = mutableDictionary(
        settings.objectForKey(profileName),
        `Terminal profile '${profileName}' must be a dictionary`
    );
    for (const key of ObjC.deepUnwrap(profile.allKeys)) {
        managedProfile.setObjectForKey(profile.objectForKey(key), key);
    }
    settings.setObjectForKey(managedProfile, profileName);
    result.setObjectForKey(settings, "Window Settings");
    result.setObjectForKey(profileName, "Default Window Settings");
    result.setObjectForKey(profileName, "Startup Window Settings");
    return result;
}

function writeFixture(path, domain) {
    const data = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
        domain,
        $.NSPropertyListXMLFormat_v1_0,
        0,
        null
    );
    if (!data || !data.writeToFileAtomically(path, true)) {
        fail(`Cannot write preferences fixture: ${path}`);
    }
}

function applyProduction(profile, profileName) {
    const defaults = $.NSUserDefaults.alloc.initWithSuiteName(terminalBundleID);
    const existingDomain = defaults.persistentDomainForName(terminalBundleID);
    const domain = existingDomain
        ? mutableDictionary(existingDomain, "Terminal preference domain must be a dictionary")
        : $.NSDictionary.alloc.init;
    const reconciled = reconcileDomain(domain, profile, profileName);
    if (domain.isEqualToDictionary(reconciled)) {
        console.log("macOS Terminal profile SeaShells is already configured.");
        return;
    }

    const settings = reconciled.objectForKey("Window Settings");
    defaults.setObjectForKey(settings, "Window Settings");
    defaults.setObjectForKey(profileName, "Default Window Settings");
    defaults.setObjectForKey(profileName, "Startup Window Settings");
    if (!defaults.synchronize) {
        fail("Cannot synchronize macOS Terminal preferences");
    }

    const actualSettingsValue = defaults.dictionaryForKey("Window Settings");
    const actualSettings = actualSettingsValue
        ? mutableDictionary(
            actualSettingsValue,
            "Terminal preference 'Window Settings' must be a dictionary"
        )
        : null;
    if (!actualSettings || !actualSettings.objectForKey(profileName) ||
        ObjC.unwrap(defaults.stringForKey("Default Window Settings")) !== profileName ||
        ObjC.unwrap(defaults.stringForKey("Startup Window Settings")) !== profileName) {
        fail("macOS Terminal preferences did not retain the SeaShells profile");
    }
    console.log("Configured macOS Terminal profile SeaShells.");
}

function productionIsConfigured(profile, profileName) {
    const defaults = $.NSUserDefaults.alloc.initWithSuiteName(terminalBundleID);
    const existingDomain = defaults.persistentDomainForName(terminalBundleID);
    const domain = existingDomain
        ? mutableDictionary(existingDomain, "Terminal preference domain must be a dictionary")
        : $.NSDictionary.alloc.init;
    return domain.isEqualToDictionary(reconcileDomain(domain, profile, profileName));
}

function run(argv) {
    const options = parseArguments(argv);
    const profile = readPlist(options.profile);
    const profileName = validateProfile(profile);

    if (options.preferencesFile) {
        const domain = readPlist(options.preferencesFile);
        const reconciled = reconcileDomain(domain, profile, profileName);
        if (!domain.isEqualToDictionary(reconciled)) {
            writeFixture(options.preferencesFile, reconciled);
        }
        return;
    }

    if (productionIsConfigured(profile, profileName)) {
        console.log("macOS Terminal profile SeaShells is already configured.");
        return;
    }
    if (terminalIsRunning()) {
        $.exit(75);
    }
    applyProduction(profile, profileName);
}
