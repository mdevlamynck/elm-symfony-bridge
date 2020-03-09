function overrideDefaultsIfProvided(override, defaults) {
    let result = {};

    for (const key in defaults) {
        result[key] = (override.hasOwnProperty(key) && override[key] !== null)
            ? override[key]
            : defaults[key];
    }

    return result;
}

function combinations(l1, l2, callback) {
    let results = [];

    l1.forEach((e1) => {
        l2.forEach((e2) => {
            results.push(callback(e1, e2));
        });
    });

    return results;
}

function mapKey(object, key, callback) {
    if (object.hasOwnProperty(key) && object[key] !== null) {
        object[key] = callback(object[key]);
    }

    return object;
}

function setDefaultValueIfAbsent(options, key, value) {
    var actualValue = options[key];
    if (actualValue === null || typeof actualValue === 'undefined') {
        options[key] = value;
    }
}

function arrayPushIfNotPresent(array, value) {
    // Webpack 4 uses `Set`s so we check that case first.
    // Since it's a set we do not need to check for the precense of `value` in `array`.
    if (typeof array.add !== 'undefined') {
        array.add(value);
    } else if (!array.includes(value)) {
        array.push(value);
    }

    return array;
}

function onSuccess(type, data, callback) {
    if (data.type === type && data.succeeded === true) {
        callback();
    } else if (data.succeeded === true) {
        error('Expected ' + type + ' got ' + data.type + '.');
    } else {
        error(data.error);
    }
}

function error(msg, cause) {
    if (cause) {
        console.error(`[ERROR elm-symfony-bridge] ${msg}: ${cause}`);
    } else {
        console.error(`[ERROR elm-symfony-bridge] ${msg}`);
    }
}

module.exports = {
    overrideDefaultsIfProvided,
    combinations,
    mapKey,
    setDefaultValueIfAbsent,
    arrayPushIfNotPresent,
    onSuccess,
    error
};
