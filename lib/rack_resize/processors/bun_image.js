const opts = JSON.parse(Bun.argv[2]);
const { source, target, width, height, format, quality, fit } = opts;

let img = Bun.file(source).image();

if (width && height) {
  img = img.resize(width, height, { fit: fit === "fill" ? "fill" : "inside" });
} else if (width) {
  img = img.resize(width);
} else if (height) {
  // Bun.Image lacks height-only resize; derive width from source aspect ratio.
  const meta = await img.metadata();
  const w = Math.max(1, Math.round((meta.width * height) / meta.height));
  img = new Bun.Image(source).resize(w, height, { fit: "inside" });
}

const q = quality ?? 85;
const outFmt = (format || source.split(".").pop()).toLowerCase();

switch (outFmt) {
  case "jpg":
  case "jpeg": img = img.jpeg({ quality: q }); break;
  case "png":  img = img.png(); break;
  case "webp": img = img.webp({ quality: q }); break;
  case "avif": img = img.avif({ quality: q }); break;
  case "heic": img = img.heic({ quality: q }); break;
  default: throw new Error(`unsupported format: ${outFmt}`);
}

if (target) {
  await img.write(target);
} else {
  process.stdout.write(await img.bytes());
}
