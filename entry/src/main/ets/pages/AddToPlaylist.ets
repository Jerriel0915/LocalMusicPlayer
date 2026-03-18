/**
 * 添加歌曲到歌单页面
 * 显示所有歌曲，支持添加/移除歌曲到歌单
 */

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { TrackInfo } from '../models/TrackInfo';
import { Database } from '../services/Database';
import { MiniPlayer } from '../views/MiniPlayer';
import { image } from '@kit.ImageKit';
import { CoverExtractor } from '../utils/CoverExtractor';

@Entry
@Component
struct AddToPlaylistPage {
  @State private tracks: TrackInfo[] = [];
  @State private playlistTrackIds: Set<number> = new Set<number>();
  @State private isLoading: boolean = true;
  @State private playlistId: number = -1;
  @State private playlistName: string = '';

  private database: Database = Database.getInstance();

  aboutToAppear() {
    // 获取传入的歌单 ID
    const params = router.getParams() as Record<string, number | string>;
    if (params) {
      if (params.playlistId) {
        this.playlistId = params.playlistId as number;
      }
      if (params.playlistName) {
        this.playlistName = params.playlistName as string;
      }
    }
    this.loadData();
  }

  private async loadData() {
    try {
      this.isLoading = true;
      
      // 获取所有歌曲
      this.tracks = await this.database.getAllTracks();
      
      // 获取歌单中已有的歌曲 ID
      if (this.playlistId > 0) {
        const playlistTracks = await this.database.getPlaylistTracks(this.playlistId);
        this.playlistTrackIds = new Set<number>(playlistTracks.map((t: TrackInfo): number => t.id));
      }
    } catch (err) {
      console.error('加载数据失败:', err);
    } finally {
      this.isLoading = false;
    }
  }

  private async toggleTrackInPlaylist(track: TrackInfo) {
    if (this.playlistId < 0) {
      return;
    }

    try {
      if (this.playlistTrackIds.has(track.id)) {
        // 从歌单移除
        await this.database.removeTrackFromPlaylist(this.playlistId, track.id);
        this.playlistTrackIds.delete(track.id);
        promptAction.showToast({ message: `已从歌单移除` });
      } else {
        // 添加到歌单
        await this.database.addTrackToPlaylist(this.playlistId, track.id);
        this.playlistTrackIds.add(track.id);
        promptAction.showToast({ message: `已添加到歌单` });
      }
      // 强制刷新状态
      this.playlistTrackIds = new Set<number>(this.playlistTrackIds);
    } catch (err) {
      console.error('操作失败:', err);
      promptAction.showToast({ message: '操作失败' });
    }
  }

  private async navigateBack() {
    try {
      await router.back();
    } catch (err) {
      console.error('返回失败:', err);
    }
  }

  @Builder
  TrackItemBuilder(track: TrackInfo, index: number) {
    Row() {
      // 序号
      Text((index + 1).toString())
        .fontSize(16)
        .fontColor('#999999')
        .width(30)
        .textAlign(TextAlign.Center)

      // 封面
      CoverImage({ filePath: track.filePath })

      // 歌曲信息
      Column() {
        Text(track.title)
          .fontSize(16)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(track.artist)
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12, right: 8 })

      // 添加/已添加按钮
      Button() {
        if (this.playlistTrackIds.has(track.id)) {
          Image($r('app.media.added'))
            .width(24)
            .height(24)
            .fillColor('#FF4081')
        } else {
          Image($r('app.media.add'))
            .width(18)
            .height(18)
            .fillColor('#CCCCCC')
        }
      }
      .type(ButtonType.Circle)
      .backgroundColor('transparent')
      .width(44)
      .height(44)
      .onClick(() => this.toggleTrackInPlaylist(track))
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 8 })
    .backgroundColor('#FFFFFF')
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Image($r('app.media.icon_back'))
            .width(24)
            .height(24)
            .fillColor('#333333')
        }
        .type(ButtonType.Circle)
        .backgroundColor('transparent')
        .width(44)
        .height(44)
        .onClick((): void => { this.navigateBack(); })

        Text('添加歌曲')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(44).height(44)
      }
      .width('100%')
      .height(80)
      .padding({ left: 8, right: 8, top: 30 })
      .backgroundColor('#FFFFFF')

      // 歌单名称提示
      Row() {
        Text(`添加到: ${this.playlistName}`)
          .fontSize(14)
          .fontColor('#999999')
        
        Blank()
        
        Text(`已选 ${this.playlistTrackIds.size} 首`)
          .fontSize(14)
          .fontColor('#FF4081')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 歌曲列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.tracks.length === 0) {
        Column() {
          Image($r('app.media.icon_music_note'))
            .width(80)
            .height(80)
            .fillColor('#CCCCCC')
            .margin({ bottom: 16 })

          Text('暂无歌曲')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.tracks, (track: TrackInfo, index: number) => {
            ListItem() {
              this.TrackItemBuilder(track, index)
            }
          }, (track: TrackInfo): string => track.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#EEEEEE' })
        .padding({ bottom: 64 })
      }

      // 迷你播放条
      Column() {
        MiniPlayer({
          onExpand: (): void => {
            router.pushUrl({ url: 'pages/Player' });
          }
        })
      }
      .width('100%')
      .position({ bottom: 0 })
      .zIndex(100)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}

/**
 * 封面图片组件
 */
@Component
struct CoverImage {
  @Prop filePath: string = '';
  @State coverPixelMap: image.PixelMap | null = null;

  aboutToAppear() {
    this.loadCover();
  }

  private async loadCover() {
    if (!this.filePath) {
      return;
    }
    
    const cachedCover = CoverExtractor.getCachedCover(this.filePath);
    if (cachedCover) {
      this.coverPixelMap = cachedCover;
      return;
    }
    
    try {
      const pixelMap = await CoverExtractor.extractCoverPixelMap(this.filePath);
      this.coverPixelMap = pixelMap;
    } catch (err) {
      console.error('加载封面失败:', err);
    }
  }

  build() {
    if (this.coverPixelMap) {
      Image(this.coverPixelMap)
        .width(48)
        .height(48)
        .borderRadius(4)
        .objectFit(ImageFit.Cover)
    } else {
      Column() {
        Image($r('app.media.icon_music_note'))
          .width(24)
          .height(24)
          .fillColor('#CCCCCC')
      }
      .width(48)
      .height(48)
      .backgroundColor('#F0F0F0')
      .borderRadius(4)
      .justifyContent(FlexAlign.Center)
    }
  }
}
