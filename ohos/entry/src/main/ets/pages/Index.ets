import common from '@ohos.app.ability.common';
import {
  HdsAnimationMode,
  HdsTabs,
  HdsTabsController,
  hdsMaterial,
} from '@kit.UIDesignKit';
import { FlutterPage } from '@ohos/flutter_ohos';
import AppPlugin from '../plugins/AppPlugin';
import {
  EVENT_SET_NATIVE_TAB_BAR_VISIBLE,
  EVENT_SET_NATIVE_TAB_INDEX,
  EVENT_SYNC_NATIVE_TABS,
  NativeTabItem,
  NativeTabSyncPayload,
} from '../plugins/native_tab_types';

const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS';

let storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext;
  private tabsController: HdsTabsController = new HdsTabsController();
  @LocalStorageLink('viewId') viewId: string = '';
  @State currentIndex: number = 0;
  @State items: NativeTabItem[] = [
    { id: 'dashboard', label: '仪表盘' },
    { id: 'profiles', label: '配置' },
    { id: 'tools', label: '工具' },
  ];
  private syncingFromFlutter: boolean = false;
  private tabBarHidden: boolean = false;

  aboutToAppear(): void {
    this.context.eventHub.on(EVENT_SYNC_NATIVE_TABS, (payload: NativeTabSyncPayload) => {
      this.applyTabSync(payload);
    });
    this.context.eventHub.on(EVENT_SET_NATIVE_TAB_INDEX, (index: number) => {
      this.applyTabIndex(index);
    });
    this.context.eventHub.on(EVENT_SET_NATIVE_TAB_BAR_VISIBLE, (payload: TabBarVisiblePayload) => {
      this.applyTabBarVisible(payload);
    });
    const pending = AppPlugin.consumePendingTabSync();
    if (pending !== null) {
      this.applyTabSync(pending);
    }
  }

  aboutToDisappear(): void {
    this.context.eventHub.off(EVENT_SYNC_NATIVE_TABS);
    this.context.eventHub.off(EVENT_SET_NATIVE_TAB_INDEX);
    this.context.eventHub.off(EVENT_SET_NATIVE_TAB_BAR_VISIBLE);
  }

  private applyTabSync(payload: NativeTabSyncPayload): void {
    if (payload.items.length > 0) {
      this.items = payload.items;
    }
    this.applyTabIndex(payload.index);
  }

  private applyTabIndex(index: number): void {
    const nextIndex = Math.min(Math.max(index, 0), Math.max(this.items.length - 1, 0));
    if (this.currentIndex === nextIndex) {
      return;
    }
    this.syncingFromFlutter = true;
    this.currentIndex = nextIndex;
    this.tabsController.changeIndex(nextIndex);
    this.syncingFromFlutter = false;
  }

  private applyTabBarVisible(payload: TabBarVisiblePayload): void {
    if (payload.visible === !this.tabBarHidden) {
      return;
    }
    this.tabBarHidden = !payload.visible;
    const mode = payload.mode === 'click'
      ? HdsAnimationMode.CLICK_ANIMATION
      : HdsAnimationMode.SCROLL_ANIMATION;
    if (payload.visible) {
      this.tabsController.applyShowAnimation(mode);
    } else {
      this.tabsController.applyHideAnimation(mode);
    }
  }

  private selectTab(index: number): void {
    if (index < 0 || index >= this.items.length) {
      return;
    }
    if (this.tabBarHidden) {
      this.tabBarHidden = false;
      this.tabsController.applyShowAnimation(HdsAnimationMode.CLICK_ANIMATION);
    }
    if (this.currentIndex !== index) {
      this.currentIndex = index;
      this.tabsController.changeIndex(index);
    }
    AppPlugin.notifyNativeTabSelected(index);
  }

  private iconOf(id: string): Resource {
    switch (id) {
      case 'proxies':
        return $r('app.media.ic_proxies');
      case 'profiles':
        return $r('app.media.ic_profiles');
      case 'tools':
        return $r('app.media.ic_tools');
      default:
        return $r('app.media.ic_dashboard');
    }
  }

  build() {
    Column() {
      Stack() {
        FlutterPage({ viewId: this.viewId })
          .width('100%')
          .height('100%')

        HdsTabs({
          barPosition: BarPosition.End,
          index: this.currentIndex,
          controller: this.tabsController,
        }) {
          ForEach(this.items, (item: NativeTabItem) => {
            TabContent() {
              Column()
                .width('100%')
                .height('100%')
                .hitTestBehavior(HitTestMode.None)
            }
            .tabBar(BottomTabBarStyle.of(this.iconOf(item.id), item.label))
          }, (item: NativeTabItem) => item.id)
        }
        .vertical(false)
        .scrollable(false)
        .animationDuration(0)
        .barBackgroundColor(Color.Transparent)
        .hitTestBehavior(HitTestMode.Transparent)
        .barOverlap(true)
        .barFloatingStyle({
          adaptToHandedness: true,
          barBottomMargin: 12,
          barSideMargin: 24,
          gradientMask: {
            maskColor: '#66000000',
            maskHeight: 92,
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
          },
        })
        .width('100%')
        .height('100%')
        .onTabBarClick((index: number) => {
          this.selectTab(index);
        })
        .onChange((index: number) => {
          if (this.syncingFromFlutter) {
            return;
          }
          this.selectTab(index);
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS);
    return true;
  }
}

interface TabBarVisiblePayload {
  visible: boolean;
  mode: string;
}
