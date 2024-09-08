import fs from './filesystem.js';
import symfony from './symfony.js';
import utils from './utils.js';

async function transpile(global) {
    if (!global.options.enableRouting) {
        return;
    }

    const content = await symfony.queryRouting(global.options);

    await utils.whenChanged('routing', content, async () => {
        const data = await utils.callElm(global.transpiler, {
            routing: {
                urlPrefix: global.options.dev ? global.options.urlPrefix : '',
                content: content,
                version: global.options.elmVersion,
                envVariables: global.options.envVariables,
            }
        });

        if (data.succeeded) {
            await fs.writeFile(global.options.elmRoot + '/Routing.elm', data.content);
        } else {
            utils.error(data.error)
        }
    });
}

module.exports = {
    transpile,
};
