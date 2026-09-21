export const EVENT_SYNC_NATIVE_TABS = 'EVENT_SYNC_NATIVE_TABS';
export const EVENT_SET_NATIVE_TAB_INDEX = 'EVENT_SET_NATIVE_TAB_INDEX';
export const EVENT_SET_NATIVE_TAB_BAR_VISIBLE = 'EVENT_SET_NATIVE_TAB_BAR_VISIBLE';

export interface NativeTabItem {
  id: string;
  label: string;
}

export interface NativeTabSyncPayload {
  items: NativeTabItem[];
  index: number;
}
