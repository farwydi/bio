import fs from 'node:fs'
import tailwindcss from "tailwindcss";
import autoprefixer from "autoprefixer";
import cssnano from "cssnano";
import {CssShortener} from "css-shortener";
import selectorParser from "postcss-selector-parser";

const PROD = process.env.NODE_ENV === 'production';

export default {
  plugins: [
    tailwindcss,
    autoprefixer,
    PROD ? cssnano({
      preset: [
        "default", {
          discardComments: {
            removeAll: true
          }
        }
      ]
    }) : null,
    PROD ? {
      postcssPlugin: 'class-name-shortener',
      prepare() {
        const cssShortener = new CssShortener();
        const selectorProcessor = selectorParser(selectors => {
          selectors.walkClasses(
            (node) => {
              node.value = cssShortener.shortenClassName(node.value);
            }
          );
        });
        return {
          async Rule(ruleNode) {
            try {
              await selectorProcessor.process(ruleNode);
            } catch (err) {
              console.error(err);
            }
          },
          async OnceExit() {
            try {
              fs.writeFileSync('./cssmap.json', JSON.stringify(cssShortener.map), 'utf-8')
            } catch (err) {
              console.error(err);
            }
          }
        };
      }
    } : null,
  ]
}
