import fs from './filesystem.js';
import { glob } from 'glob';
import symfony from './symfony.js';
import utils from './utils.js';

async function transpile(global) {
    if (!global.options.enableTranslations) {
        return;
    }

    await symfony.dumpTranslations(global.options);
    const files = await glob(global.options.outputFolder + '/translations/*/' + global.options.lang + '.json');

    await Promise.all(files.map(async file => {
        const content = await fs.readFile(file);

        await utils.whenChanged(`translations ${file}`, content, async () => {
            const data = await utils.callElm(global.transpiler, {
                translation: {
                    name: file,
                    content: content,
                    version: global.options.elmVersion,
                    envVariables: global.options.envVariables,
                }
            });

            if (data.succeeded) {
                await fs.writeFile(global.options.elmRoot + '/' + data.file.name, data.file.content);
            } else {
                utils.error(data.error)
            }
        });
    }));
}

module.exports = {
    transpile,
};
