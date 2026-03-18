/**
 * 专辑封面和元数据提取器
 * 使用 AVMetadataExtractor 从音频文件中提取内嵌封面和时长
 */

import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

/**
 * 封面提取结果
 */
export interface CoverResult {
  // 封面图片的 PixelMap
  pixelMap: image.PixelMap | null;
  // 封面图片数据（用于保存）
  imageData: ArrayBuffer | null;
}

/**
 * 音频元数据结果
 */
export interface AudioMetadataResult {
  // 封面图片
  cover: image.PixelMap | null;
  // 时长（毫秒）
  duration: number;
  // 标题
  title: string;
  // 艺术家
  artist: string;
  // 专辑
  album: string;
}

/**
 * 封面提取器
 */
export class CoverExtractor {
  // 封面缓存（避免重复提取）
  private static coverCache: Map<string, image.PixelMap> = new Map();
  // 时长缓存
  private static durationCache: Map<string, number> = new Map();
  
  /**
   * 从音频文件提取所有元数据（封面、时长等）
   * @param filePath 音频文件路径
   * @returns 元数据结果
   */
  static async extractMetadata(filePath: string): Promise<AudioMetadataResult> {
    const result: AudioMetadataResult = {
      cover: null,
      duration: 0,
      title: '',
      artist: '',
      album: ''
    };
    
    // 检查缓存
    if (CoverExtractor.coverCache.has(filePath)) {
      result.cover = CoverExtractor.coverCache.get(filePath) || null;
    }
    if (CoverExtractor.durationCache.has(filePath)) {
      result.duration = CoverExtractor.durationCache.get(filePath) || 0;
    }
    
    // 如果都有缓存，直接返回
    if (result.cover && result.duration > 0) {
      return result;
    }
    
    let file: fileIo.File | null = null;
    let extractor: media.AVMetadataExtractor | null = null;
    
    try {
      // 创建 AVMetadataExtractor
      extractor = await media.createAVMetadataExtractor();
      
      // 使用文件描述符设置数据源
      file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const fileSize = fileIo.statSync(filePath).size;
      
      const fdSrc: media.AVFileDescriptor = {
        fd: file.fd,
        offset: 0,
        length: fileSize
      };
      
      extractor.fdSrc = fdSrc;
      
      // 获取元数据（包含时长）
      const metadata = await extractor.fetchMetadata();
      console.info(`[CoverExtractor] 元数据: duration=${metadata.duration}, title=${metadata.title}`);
      
      // 获取时长（毫秒）- duration 可能是字符串或数字
      const durationValue = metadata.duration;
      if (durationValue) {
        const durationNum = typeof durationValue === 'string' ? parseInt(durationValue, 10) : Number(durationValue);
        if (!isNaN(durationNum) && durationNum > 0) {
          result.duration = durationNum;
          CoverExtractor.durationCache.set(filePath, result.duration);
          console.info(`[CoverExtractor] 时长: ${result.duration}ms`);
        }
      }
      
      // 获取标题、艺术家、专辑
      if (metadata.title) {
        result.title = metadata.title;
      }
      if (metadata.artist) {
        result.artist = metadata.artist;
      }
      if (metadata.album) {
        result.album = metadata.album;
      }
      
      // 获取封面
      if (!result.cover) {
        const pixelMap = await extractor.fetchAlbumCover();
        if (pixelMap) {
          result.cover = pixelMap;
          CoverExtractor.coverCache.set(filePath, pixelMap);
          console.info('[CoverExtractor] 封面提取成功');
        } else {
          console.info('[CoverExtractor] 未找到封面数据');
        }
      }
      
      // 关闭文件
      fileIo.closeSync(file);
      file = null;
      
      // 释放资源
      await extractor.release();
      extractor = null;
      
    } catch (err) {
      console.error('[CoverExtractor] 提取元数据失败:', err);
      // 确保资源释放
      if (file) {
        try {
          fileIo.closeSync(file);
        } catch (e) {
          // 忽略关闭错误
        }
      }
      if (extractor) {
        try {
          await extractor.release();
        } catch (e) {
          // 忽略释放错误
        }
      }
    }
    
    return result;
  }
  
  /**
   * 从音频文件提取时长
   * @param filePath 音频文件路径
   * @returns 时长（毫秒）
   */
  static async extractDuration(filePath: string): Promise<number> {
    // 检查缓存
    if (CoverExtractor.durationCache.has(filePath)) {
      return CoverExtractor.durationCache.get(filePath) || 0;
    }
    
    const metadata = await CoverExtractor.extractMetadata(filePath);
    return metadata.duration;
  }
  
  /**
   * 从音频文件提取专辑封面
   * @param filePath 音频文件路径
   * @returns 封面提取结果
   */
  static async extractCover(filePath: string): Promise<CoverResult> {
    const result: CoverResult = {
      pixelMap: null,
      imageData: null
    };
    
    // 检查缓存
    if (CoverExtractor.coverCache.has(filePath)) {
      result.pixelMap = CoverExtractor.coverCache.get(filePath) || null;
      return result;
    }
    
    const metadata = await CoverExtractor.extractMetadata(filePath);
    result.pixelMap = metadata.cover;
    
    return result;
  }
  
  /**
   * 从音频文件提取封面并返回 PixelMap
   * @param filePath 音频文件路径
   * @returns PixelMap 或 null
   */
  static async extractCoverPixelMap(filePath: string): Promise<image.PixelMap | null> {
    const result = await CoverExtractor.extractCover(filePath);
    return result.pixelMap;
  }
  
  /**
   * 清除所有缓存
   */
  static clearCache(): void {
    CoverExtractor.coverCache.clear();
    CoverExtractor.durationCache.clear();
  }
  
  /**
   * 从缓存中获取封面
   * @param filePath 文件路径
   * @returns PixelMap 或 null
   */
  static getCachedCover(filePath: string): image.PixelMap | null {
    return CoverExtractor.coverCache.get(filePath) || null;
  }
  
  /**
   * 从缓存中获取时长
   * @param filePath 文件路径
   * @returns 时长（毫秒）或 0
   */
  static getCachedDuration(filePath: string): number {
    return CoverExtractor.durationCache.get(filePath) || 0;
  }
}
