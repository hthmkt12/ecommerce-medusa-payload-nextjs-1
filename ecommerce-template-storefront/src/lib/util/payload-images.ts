import type {
  PayloadImage,
  PayloadImageItem,
  StoreProductWithPayload,
} from "../../types/global"

const PAYLOAD_SERVER_URL =
  process.env.NEXT_PUBLIC_PAYLOAD_SERVER_URL || "http://localhost:3000"

/**
 * Canonical resolver for every media URL coming from Payload.
 *
 * Handles all three shapes a media URL can arrive in:
 * - Absolute S3/R2 URLs (when the CMS storage adapter is enabled) -> pass through
 * - Absolute localhost URLs (Medusa-served images in local dev) -> swap host
 *   to the backend container name so SSR can reach them
 * - Payload-relative paths (`/api/media/file/<file>`, local-disk storage)
 *   -> prefix with the Payload server URL
 */
export function resolvePayloadMediaUrl(url: string): string {
  if (/^https?:\/\//i.test(url)) {
    if (url.includes("localhost")) {
      return url.replace(
        "localhost",
        process.env.NEXT_PUBLIC_BACKEND_CONTAINER_NAME || "backend"
      )
    }
    return url
  }

  return `${PAYLOAD_SERVER_URL}${url.startsWith("/") ? "" : "/"}${url}`
}

export function getProductImages(product: StoreProductWithPayload) {
  const payloadImages =
    product?.payload_product?.images?.map((image) => ({
      id: image.id,
      url: resolvePayloadMediaUrl(image.image.url),
    })) || []

  return payloadImages.length > 0 ? payloadImages : product.images || []
}

/**
 * @deprecated use {@link resolvePayloadMediaUrl} directly.
 * Kept for existing call sites; now resolves instead of stripping the path.
 */
export function formatPayloadImageUrl(url: string): string {
  return resolvePayloadMediaUrl(url)
}

export function getPayloadImage(url: string): string {
  return resolvePayloadMediaUrl(url)
}

export function parsePayloadImage(image: PayloadImage): PayloadImage {
  return {
    ...image,
    url: getPayloadImage(image.url),
    thumbnailURL: getPayloadImage(image.thumbnailURL),
  }
}

export function parsePayloadImageItems(
  imageItems: PayloadImageItem[]
): PayloadImageItem[] {
  return imageItems.map((imageItem) => ({
    ...imageItem,
    image: parsePayloadImage(imageItem.image),
  }))
}
