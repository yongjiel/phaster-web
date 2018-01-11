// LEGACY CODE FOR DOWNLOADING IMAGES AS SVGS
// var out$ = typeof exports != 'undefined' && exports || this;

// var doctype = '<?xml version="1.0" standalone="no"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">';

// function isExternal(url) {
//   return url && url.lastIndexOf('http',0) == 0 && url.lastIndexOf(window.location.host) == -1;
// }

// function inlineImages(el, callback) {
//   var images = el.querySelectorAll('image');
//   var left = images.length;
//   if (left == 0) {
//     return callback();
//   }
//   for (var i = 0; i < images.length; i++) {
//     (function(image) {
//       var href = image.getAttributeNS("http://www.w3.org/1999/xlink", "href");
//       if (href) {
//         if (isExternal(href.value)) {
//           console.warn("Cannot render embedded images linking to external hosts: "+href.value);
//           return;
//         }
//       }
//       var canvas = document.createElement('canvas');
//       var ctx = canvas.getContext('2d');
//       var img = new Image();
//       href = href || image.getAttribute('href');
//       img.src = href;
//       img.onload = function() {
//         canvas.width = img.width;
//         canvas.height = img.height;
//         ctx.drawImage(img, 0, 0);
//         image.setAttributeNS("http://www.w3.org/1999/xlink", "href", canvas.toDataURL('image/png'));
//         left--;
//         if (left == 0) {
//           callback();
//         }
//       }
//       img.onerror = function() {
//         console.log("Could not load "+href);
//         left--;
//         if (left == 0) {
//           return callback();
//         }
//       }
//     })(images[i]);
//   }
// }

// function styles(el, selectorRemap) {
//   var css = "";
//   var sheets = document.styleSheets;
//   for (var i = 0; i < sheets.length; i++) {
//     try {
//       var rules = sheets[i].cssRules;
//     } catch (e) {
//       console.warn("Stylesheet could not be loaded: "+sheets[i].href);
//       continue;
//     }

//     if (rules != null) {
//       for (var j = 0; j < rules.length; j++) {
//         var rule = rules[j];
//         if (typeof(rule.style) != "undefined") {
//           var match = null;
//           try {
//             match = el.querySelector(rule.selectorText);
//           } catch(err) {
//             console.warn('Invalid CSS selector "' + rule.selectorText + '"', err);
//           }
//           if (match) {
//             var selector = selectorRemap ? selectorRemap(rule.selectorText) : rule.selectorText;
//             css += selector + " { " + rule.style.cssText + " }\n";
//           } else if(rule.cssText.match(/^@font-face/)) {
//             css += rule.cssText + '\n';
//           }
//         }
//       }
//     }
//   }
//   return css;
// }

// function getDimension(el, clone, dim) {
//   var v = (el.viewBox.baseVal && el.viewBox.baseVal[dim]) ||
//     (clone.getAttribute(dim) !== null && !clone.getAttribute(dim).match(/%$/) && parseInt(clone.getAttribute(dim))) ||
//     el.getBoundingClientRect()[dim] ||
//     parseInt(clone.style[dim]) ||
//     parseInt(window.getComputedStyle(el).getPropertyValue(dim));
//   return (typeof v === 'undefined' || v === null || isNaN(parseFloat(v))) ? 0 : v;
// }

// function reEncode(data) {
//   data = encodeURIComponent(data);
//   data = data.replace(/%([0-9A-F]{2})/g, function(match, p1) {
//     var c = String.fromCharCode('0x'+p1);
//     return c === '%' ? '%25' : c;
//   });
//   return decodeURIComponent(data);
// }

// function svgAsData(el, options) {
//   options = options || {};
//   options.scale = options.scale || 1;
//   var xmlns = "http://www.w3.org/2000/xmlns/";

//   return inlineImages(el, function() {
//     var outer = document.createElement("div");
//     var clone = el.cloneNode(true);
//     var width, height;
//     if(el.tagName == 'svg') {
//       width = options.width || getDimension(el, clone, 'width');
//       height = options.height || getDimension(el, clone, 'height');
//     } else if(el.getBBox) {
//       var box = el.getBBox();
//       width = box.x + box.width;
//       height = box.y + box.height;
//       clone.setAttribute('transform', clone.getAttribute('transform').replace(/translate\(.*?\)/, ''));

//       var svg = document.createElementNS('http://www.w3.org/2000/svg','svg')
//       svg.appendChild(clone)
//       clone = svg;
//     } else {
//       console.error('Attempted to render non-SVG element', el);
//       return;
//     }

//     clone.setAttribute("version", "1.1");
//     clone.setAttributeNS(xmlns, "xmlns", "http://www.w3.org/2000/svg");
//     clone.setAttributeNS(xmlns, "xmlns:xlink", "http://www.w3.org/1999/xlink");
//     clone.setAttribute("width", width * options.scale);
//     clone.setAttribute("height", height * options.scale);
//     clone.setAttribute("viewBox", [
//       options.left || 0,
//       options.top || 0,
//       width,
//       height
//     ].join(" "));

//     outer.appendChild(clone);

//     var css = styles(el, options.selectorRemap);
//     var s = document.createElement('style');
//     s.setAttribute('type', 'text/css');
//     s.innerHTML = "<![CDATA[\n" + css + "\n]]>";
//     var defs = document.createElement('defs');
//     defs.appendChild(s);
//     clone.insertBefore(defs, clone.firstChild);

//     var svg = doctype + outer.innerHTML;
//     return svg;
//   });
// }

// function submit_download_form(svg_id, output_format, filename)
//   {

//     // Get the d3js SVG element
//     var svg = document.getElementById(svg_id);
//     var svg_xml = svgAsData(svg);

//     var form = document.getElementById("imageform");
//     form['output_format'].value = output_format;
//     form['data'].value = svg_xml;
//     form['filename'].value = filename;
//     form.submit();
//   }