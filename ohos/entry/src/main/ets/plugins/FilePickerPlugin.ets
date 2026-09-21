import {
  AbilityPluginBinding,
  BinaryMessenger,
  FlutterPlugin,
  FlutterPluginBinding,
  Log,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { common, UIAbility } from '@kit.AbilityKit';
import Want from '@ohos.app.ability.Want';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fileUri from '@ohos.file.fileuri';
import { fileIo as fs } from '@kit.CoreFileKit';

import { FilePickerDelegate } from './FilePickerDelegate';
import { FilePickerUtils } from './FilePickerUtils';

const CHANNEL = 'miguelruivo.flutter.plugins.filepicker';
const TAG = 'FilePickerPlugin';

export default class FilePickerPlugin implements FlutterPlugin, MethodCallHandler {
  private pluginBinding: FlutterPluginBinding | null = null;
  private abilityBinding: AbilityPluginBinding | null = null;
  private channel: MethodChannel | null = null;
  private ability: UIAbility | null = null;
  private delegate: FilePickerDelegate | null = null;

  getUniqueClassName(): string {
    return 'FilePickerPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = binding;
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.onDetachedFromAbility();
    this.pluginBinding = null;
  }

  onDetachedFromAbility(): void {
    this.delegate?.cancelPendingResult(
      'no_activity',
      'File picker ability detached before completion',
    );
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.abilityBinding = null;
    this.ability = null;
    this.delegate = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding;
    this.ability = binding.getAbility();
    this.delegate = new FilePickerDelegate(this.ability);
    this.setup(this.pluginBinding?.getBinaryMessenger() as BinaryMessenger);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    Log.i(TAG, `onMethodCall method=${call.method}`);
    if (this.ability === null || this.delegate === null) {
      result.error('no_activity', 'file picker plugin requires a foreground ability', null);
      return;
    }
    const args = (call.args as Map<string, Object>) ?? new Map<string, Object>();
    if (call.method === 'pickImageFromGallery') {
      void this.pickImageFromGallery(result);
      return;
    }
    if (call.method === 'captureImageForFlClash') {
      void this.captureImageForFlClash(result);
      return;
    }
    if (call.method === 'pickForFlClash') {
      const allowMultipleSelection =
        (args.get('allowMultipleSelection') as boolean | undefined) ?? false;
      const allowedExtensions = (args.get('allowedExtensions') as Array<string> | undefined) ?? [];
      const initialDirectory = (args.get('initialDirectory') as string | undefined) ?? '';
      const normalizedExtensions = allowedExtensions.map((item) => item.toLowerCase());
      const imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic'];
      const fileType =
        normalizedExtensions.length > 0 &&
          normalizedExtensions.every((item) => imageExtensions.includes(item))
        ? 'image'
        : allowedExtensions.length > 0
        ? 'custom'
        : 'any';
      this.delegate.pickUrisOnly(
        fileType,
        allowMultipleSelection,
        allowedExtensions,
        initialDirectory,
        result,
      );
      return;
    }
    if (call.method === 'readForFlClash') {
      const uri = (args.get('uri') as string | undefined) ?? '';
      const withData = (args.get('withData') as boolean | undefined) ?? false;
      void this.delegate.readPickedFile(uri, withData, result);
      return;
    }
    if (call.method === 'clear') {
      result.success(FilePickerUtils.clearCache(this.ability.context));
      return;
    }
    if (call.method === 'save') {
      const fileName = (args.get('fileName') as string | undefined) ?? 'file';
      const initialDirectory = (args.get('initialDirectory') as string | undefined) ?? '';
      const allowedExtensions = (args.get('allowedExtensions') as Array<string> | undefined) ?? [];
      const bytes = (args.get('bytes') as Uint8Array | undefined) ?? new Uint8Array();
      this.delegate.saveFile([fileName], initialDirectory, allowedExtensions, bytes, result);
      return;
    }

    const allowMultipleSelection =
      (args.get('allowMultipleSelection') as boolean | undefined) ?? false;
    const allowedExtensions = (args.get('allowedExtensions') as Array<string> | undefined) ?? [];
    const withData = (args.get('withData') as boolean | undefined) ?? false;
    this.delegate.startFileExplorer(
      call.method,
      allowMultipleSelection,
      withData,
      allowedExtensions,
      result,
    );
  }

  private async captureImageForFlClash(result: MethodResult): Promise<void> {
    if (this.ability === null) {
      result.error('no_activity', 'file picker plugin requires a foreground ability', null);
      return;
    }
    const context = this.ability.context as common.UIAbilityContext;
    const outputPath = `${context.cacheDir}/flclash-camera-${Date.now()}.jpg`;
    try {
      const outputFile = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.closeSync(outputFile);
      const want: Want = {
        action: 'ohos.want.action.imageCapture',
        type: 'image/*',
        uri: fileUri.getUriFromPath(outputPath),
      };
      context.startAbilityForResult(want, async (error, abilityResult) => {
        if (error || abilityResult?.resultCode !== 0) {
          result.success(null);
          return;
        }
        const uri = abilityResult.want?.uri ?? fileUri.getUriFromPath(outputPath);
        try {
          await FilePickerUtils.prepareReadPermission(uri);
          const file = await FilePickerUtils.openFileStream(context, uri, true);
          result.success(file?.toMap() ?? null);
        } catch (readError) {
          result.error('camera_read_failed', String(readError), null);
        }
      });
    } catch (error) {
      result.error('camera_capture_failed', String(error), null);
    }
  }

  private async pickImageFromGallery(result: MethodResult): Promise<void> {
    if (this.ability === null) {
      result.error('no_activity', 'file picker plugin requires a foreground ability', null);
      return;
    }
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const selected = await photoPicker.select(options);
      const uri = selected.photoUris?.[0] ?? '';
      if (!uri) {
        result.success(null);
        return;
      }
      await FilePickerUtils.prepareReadPermission(uri);
      const file = await FilePickerUtils.openFileStream(
        this.ability.context as common.UIAbilityContext,
        uri,
        true,
      );
      result.success(file?.toMap() ?? null);
    } catch (error) {
      Log.e(TAG, `pickImageFromGallery failed: ${String(error)}`);
      result.error('gallery_pick_failed', String(error), null);
    }
  }

  private setup(messenger: BinaryMessenger): void {
    this.channel = new MethodChannel(messenger, CHANNEL);
    this.channel.setMethodCallHandler(this);
  }
}
