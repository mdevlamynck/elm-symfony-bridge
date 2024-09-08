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

    l1.forEach(e1 => {
        l2.forEach(e2 => {
            results.push(callback(e1, e2));
        });
    });

    return results;
}

function merge(object = {}, defaultObject = {}) {
    return Object.assign({}, defaultObject, object);
}

function setDefaultValueIfAbsent(options, key, value) {
    var actualValue = options[key];

    if (actualValue === null || typeof actualValue === 'undefined') {
        options[key] = value;
    }
}

function arrayAny(array, predicate) {
    for (const value of array) {
        if (predicate(value)) {
            return true;
        }
    }

    return false;
}

module.exports = {
    arrayAny,
    combinations,
    merge,
    overrideDefaultsIfProvided,
    setDefaultValueIfAbsent,
};
