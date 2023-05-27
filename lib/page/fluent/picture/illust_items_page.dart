import 'package:bot_toast/bot_toast.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/fluent/ban_page.dart';
import 'package:pixez/component/fluent/painter_avatar.dart';
import 'package:pixez/component/fluent/pixiv_image.dart';
import 'package:pixez/component/null_hero.dart';
import 'package:pixez/component/selectable_html.dart';
import 'package:pixez/component/star_icon.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/fluentui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/ban_illust_id.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/page/fluent/comment/comment_page.dart';
import 'package:pixez/page/fluent/picture/picture_list_page.dart';
import 'package:pixez/page/fluent/picture/row_card.dart';
import 'package:pixez/page/fluent/picture/tag_for_illust_page.dart';
import 'package:pixez/page/fluent/picture/ugoira_loader.dart';
import 'package:pixez/page/fluent/user/users_page.dart';
import 'package:pixez/page/fluent/zoom/photo_zoom_page.dart';
import 'package:pixez/page/picture/illust_about_store.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/user/user_store.dart';
import 'package:share_plus/share_plus.dart';

abstract class IllustItemsPage extends StatefulWidget {
  final int id;
  final String? heroString;
  final IllustStore? store;

  const IllustItemsPage({
    Key? key,
    required this.id,
    this.heroString,
    this.store,
  }) : super(key: key);
}

abstract class IllustItemsPageState extends State<IllustItemsPage>
    with AutomaticKeepAliveClientMixin {
  UserStore? userStore;
  late IllustStore illustStore;
  late IllustAboutStore aboutStore;
  late ScrollController _scrollController;
  late EasyRefreshController refreshController;
  bool tempView = false;

  @override
  void initState() {
    // widget.relay.more =
    //     () => buildshowBottomSheet(context, _illustStore.illusts!);

    refreshController = EasyRefreshController(
        controlFinishLoad: true, controlFinishRefresh: true);
    _scrollController = ScrollController();
    illustStore = widget.store ?? IllustStore(widget.id, null);
    illustStore.fetch();
    aboutStore =
        IllustAboutStore(widget.id, refreshController: refreshController);

    // Load More Detecter
    _scrollController.addListener(() {
      if (_scrollController.position.pixels + 300 >
          _scrollController.position.maxScrollExtent) {
        refreshController.callLoad();
      }
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant IllustItemsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      illustStore = widget.store ?? IllustStore(widget.id, null);
      illustStore.fetch();
      aboutStore = IllustAboutStore(widget.id);
      LPrinter.d("state change");
    }
  }

  void _loadAbout() {
    if (mounted &&
        _scrollController.hasClients &&
        _scrollController.offset + 180 >=
            _scrollController.position.maxScrollExtent &&
        aboutStore.illusts.isEmpty) aboutStore.fetch();
  }

  @override
  void dispose() {
    illustStore.dispose();
    _scrollController.dispose();
    refreshController.dispose();
    super.dispose();
  }

  final _flyoutController = FlyoutController();
  final _flyoutKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      content: Observer(builder: (_) {
        if (!tempView)
          for (var i in muteStore.banillusts) {
            if (i.illustId == widget.id.toString()) {
              return BanPage(
                name: "${I18n.of(context).illust}\n${i.name}\n",
                onPressed: () {
                  setState(() {
                    tempView = true;
                  });
                },
              );
            }
          }
        if (!tempView && illustStore.illusts != null) {
          for (var j in muteStore.banUserIds) {
            if (j.userId == illustStore.illusts!.user.id.toString()) {
              return BanPage(
                name: "${I18n.of(context).painter}\n${j.name}\n",
                onPressed: () {
                  setState(() {
                    tempView = true;
                  });
                },
              );
            }
          }
          for (var t in muteStore.banTags) {
            for (var t1 in illustStore.illusts!.tags) {
              if (t.name == t1.name)
                return BanPage(
                  name: "${I18n.of(context).tag}\n${t.name}\n",
                  onPressed: () {
                    setState(() {
                      tempView = true;
                    });
                  },
                );
            }
          }
        }
        return Stack(
          alignment: AlignmentDirectional.bottomEnd,
          children: [
            buildContent(context, illustStore.illusts),
            Container(
              margin: EdgeInsets.only(right: 8.0, bottom: 8.0),
              child: FlyoutTarget(
                key: _flyoutKey,
                controller: _flyoutController,
                child: GestureDetector(
                  child: ButtonTheme(
                    child: IconButton(
                      icon: Observer(
                        builder: (_) => StarIcon(
                          state: illustStore.state,
                        ),
                      ),
                      onPressed: illustStore.star,
                    ),
                    data: ButtonThemeData(
                      iconButtonStyle: ButtonStyle(
                        backgroundColor: ButtonState.all(
                          FluentTheme.of(context).inactiveBackgroundColor,
                        ),
                        shadowColor: ButtonState.all(
                          FluentTheme.of(context).shadowColor,
                        ),
                        shape: ButtonState.all(CircleBorder()),
                      ),
                    ),
                  ),
                  onSecondaryTapUp: (details) => _flyoutController.showFlyout(
                    position: getPosition(context, _flyoutKey, details),
                    barrierColor: Colors.black.withOpacity(0.1),
                    builder: (context) => MenuFlyout(
                      color: Colors.transparent,
                      items: [
                        MenuFlyoutItem(
                          text: Text(I18n.of(context).favorited_tag),
                          onPressed: () async {
                            await showBookMarkTag();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        );
      }),
    );
  }

  Widget colorText(String text, BuildContext context) => Container(
        child: Text(
          text,
          style: TextStyle(color: FluentTheme.of(context).accentColor),
        ),
      );

  ScrollController scrollController = ScrollController();

  Widget buildContent(BuildContext context, Illusts? data);

  SliverGrid buildRecom() {
    return SliverGrid(
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          var list = aboutStore.illusts
              .map((element) => IllustStore(element.id, element))
              .toList();
          return MoreItem(
            index,
            list,
            aboutStore,
          );
        }, childCount: aboutStore.illusts.length),
        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3));
  }

  List<Widget> buildPhotoList(Illusts data, bool centerType, double height) {
    return [
      if (data.type == "ugoira")
        SliverToBoxAdapter(
          child: NullHero(
            tag: widget.heroString,
            child: UgoiraLoader(
              id: widget.id,
              illusts: data,
            ),
          ),
        ),
      if (data.type != "ugoira")
        data.pageCount == 1
            ? (centerType
                ? SliverFillRemaining(
                    child: buildPicture(data, height),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                    return buildPicture(data, height);
                  }, childCount: 1)))
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  return IllustItem(
                    index,
                    data,
                    widget,
                    icon: buildIllustsItem(index, data, height),
                    onMultiSavePressed: () async {
                      await showMutiChoiceDialog(data, context);
                    },
                  );
                }, childCount: data.metaPages.length),
              ),
    ];
  }

  Widget buildPicture(Illusts data, double height) {
    return Center(child: Builder(
      builder: (BuildContext context) {
        String url = userSetting.pictureQuality == 1
            ? data.imageUrls.large
            : data.imageUrls.medium;
        if (data.type == "manga") {
          if (userSetting.mangaQuality == 0)
            url = data.imageUrls.medium;
          else if (userSetting.mangaQuality == 1)
            url = data.imageUrls.large;
          else
            url = data.metaSinglePage!.originalImageUrl!;
        }
        Widget placeWidget = Container(height: height);
        return IllustItem(
          0,
          data,
          widget,
          icon: NullHero(
            tag: widget.heroString,
            child: PixivImage(
              url,
              fade: false,
              width: MediaQuery.of(context).size.width,
              placeWidget: (url != data.imageUrls.medium)
                  ? PixivImage(
                      data.imageUrls.medium,
                      width: MediaQuery.of(context).size.width,
                      placeWidget: placeWidget,
                      fade: false,
                    )
                  : placeWidget,
            ),
          ),
          onMultiSavePressed: () async {
            await showMutiChoiceDialog(data, context);
          },
        );
      },
    ));
  }

  Center buildErrorContent(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(':(', style: FluentTheme.of(context).typography.title),
          ),
          Text(
            '${illustStore.errorMessage}',
            maxLines: 5,
          ),
          FilledButton(
            onPressed: () {
              illustStore.fetch();
            },
            child: Text(I18n.of(context).refresh),
          )
        ],
      ),
    );
  }

  Widget buildIllustsItem(int index, Illusts illust, double height) {
    if (illust.type == "manga") {
      String url;
      if (userSetting.mangaQuality == 0)
        url = illust.metaPages[index].imageUrls!.medium;
      else if (userSetting.mangaQuality == 1)
        url = illust.metaPages[index].imageUrls!.large;
      else
        url = illust.metaPages[index].imageUrls!.original;
      if (index == 0)
        return NullHero(
          child: PixivImage(
            url,
            placeWidget: PixivImage(
              illust.metaPages[index].imageUrls!.medium,
              width: MediaQuery.of(context).size.width,
              fade: false,
            ),
            width: MediaQuery.of(context).size.width,
            fade: false,
          ),
          tag: widget.heroString,
        );
      return PixivImage(
        url,
        fade: false,
        width: MediaQuery.of(context).size.width,
        placeWidget: Container(
          height: height,
          child: Center(
            child:
                Text('$index', style: FluentTheme.of(context).typography.title),
          ),
        ),
      );
    }
    return index == 0
        ? (userSetting.pictureQuality == 1
            ? NullHero(
                child: PixivImage(
                  illust.metaPages[index].imageUrls!.large,
                  placeWidget: PixivImage(
                    illust.metaPages[index].imageUrls!.medium,
                    fade: false,
                  ),
                  fade: false,
                ),
                tag: widget.heroString,
              )
            : NullHero(
                child: PixivImage(
                  illust.metaPages[index].imageUrls!.medium,
                  fade: false,
                ),
                tag: widget.heroString,
              ))
        : PixivImage(
            userSetting.pictureQuality == 0
                ? illust.metaPages[index].imageUrls!.medium
                : illust.metaPages[index].imageUrls!.large,
            fade: false,
            placeWidget: Container(
              height: 150,
              child: Center(
                child: Text('$index',
                    style: FluentTheme.of(context).typography.title),
              ),
            ),
          );
  }

  Widget buildRow(BuildContext context, Tags f) {
    return RowCard(f);
  }

  final _nameAvatarFlyoutController = FlyoutController();
  final _nameAvatarFlyoutKey = GlobalKey();
  Widget buildNameAvatar(BuildContext context, Illusts illust) {
    if (userStore == null)
      userStore = UserStore(illust.user.id, user: illust.user);
    return Observer(builder: (_) {
      Future.delayed(Duration(seconds: 2), () {
        _loadAbout();
      });
      return FlyoutTarget(
        controller: _nameAvatarFlyoutController,
        key: _nameAvatarFlyoutKey,
        child: GestureDetector(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                  child: Container(
                    height: 70,
                    width: 70,
                    child: Stack(
                      children: <Widget>[
                        Center(
                          child: SizedBox(
                            height: 70,
                            width: 70,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: userStore!.isFollow
                                    ? Colors.yellow
                                    : FluentTheme.of(context).accentColor,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Hero(
                            tag: illust.user.profileImageUrls.medium +
                                this.hashCode.toString(),
                            child: PainterAvatar(
                              url: illust.user.profileImageUrls.medium,
                              id: illust.user.id,
                              onTap: () async {
                                await Leader.push(
                                  context,
                                  UsersPage(
                                    id: illust.user.id,
                                    userStore: userStore,
                                    heroTag: this.hashCode.toString(),
                                  ),
                                  icon: Icon(FluentIcons.account_browser),
                                  title: Text(I18n.of(context).painter_id +
                                      '${illust.user.id}'),
                                );
                                illustStore.illusts!.user.isFollowed =
                                    userStore!.isFollow;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  padding: EdgeInsets.all(8.0)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        illust.title,
                        style: TextStyle(
                            color: FluentTheme.of(context).accentColor),
                      ),
                      Container(
                        height: 4.0,
                      ),
                      Hero(
                        tag: illust.user.name + this.hashCode.toString(),
                        child: Text(
                          illust.user.name,
                          style: FluentTheme.of(context).typography.body,
                        ),
                      ),
                      Text(
                        illust.createDate.toShortTime(),
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          onSecondaryTapUp: (details) => _nameAvatarFlyoutController.showFlyout(
            position: getPosition(context, _nameAvatarFlyoutKey, details),
            barrierColor: Colors.black.withOpacity(0.1),
            builder: (context) => MenuFlyout(
              color: Colors.transparent,
              items: [
                MenuFlyoutItem(
                  text: Text(I18n.of(context).follow),
                  onPressed: () async {
                    await userStore!.follow();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future showMutiChoiceDialog(Illusts illust, BuildContext context) async {
    List<bool> indexs = [];
    bool allOn = false;
    for (int i = 0; i < illust.metaPages.length; i++) {
      indexs.add(false);
    }
    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return ContentDialog(
              content: SafeArea(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Column(
                    children: [
                      Container(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                I18n.of(context).muti_choice_save,
                                style: FluentTheme.of(context)
                                    .typography
                                    .body
                                    ?.copyWith(
                                      color:
                                          FluentTheme.of(context).accentColor,
                                    ),
                              ),
                              Text(
                                illust.title,
                                style: FluentTheme.of(context)
                                    .typography
                                    .bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          itemBuilder: (context, index) {
                            final data = illust.metaPages[index];
                            return Container(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: buildMultiChoiceItem(
                                  data,
                                  index,
                                  indexs,
                                  illust,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      indexs[index] = value ?? false;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          itemCount: illust.metaPages.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2),
                        ),
                      ),
                      Checkbox(
                        checked: allOn,
                        content: Text(I18n.of(context).all),
                        onChanged: (value) {
                          allOn = value ?? false;
                          for (var i = 0; i < indexs.length; i++) {
                            indexs[i] = allOn;
                          }
                          setDialogState(() {});
                        },
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                FilledButton(
                  child: Text(I18n.of(context).save),
                  onPressed: () {
                    saveStore.saveChoiceImage(illust, indexs);
                    Navigator.of(context).pop();
                  },
                ),
                Button(
                  child: Text(I18n.of(context).cancel),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            );
          });
        });
  }

  Widget buildMultiChoiceItem(
    MetaPages data,
    int index,
    List<bool> indexs,
    Illusts illust, {
    required void Function(bool?) onChanged,
  }) {
    return IconButton(
      onPressed: () => onChanged(!indexs[index]),
      icon: Stack(
        children: [
          PixivImage(
            data.imageUrls!.squareMedium,
            placeWidget: Container(
              child: Center(
                child: Text(index.toString()),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Checkbox(
              checked: indexs[index],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showBookMarkTag() async {
    final result =
        await Leader.pushWithScaffold(context, TagForIllustPage(id: widget.id));
    if (result is Map) {
      LPrinter.d(result);
      String restrict = result['restrict'];
      List<String>? tags = result['tags'];
      illustStore.star(restrict: restrict, tags: tags, force: true);
    }
  }

  List<Widget> buildDetail(BuildContext context, Illusts data) {
    return [
      SliverToBoxAdapter(
        child: buildNameAvatar(context, data),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  SelectionContainer.disabled(
                      child: Text(I18n.of(context).illust_id)),
                  Container(
                    width: 10.0,
                  ),
                  colorText(data.id.toString(), context),
                  Container(
                    width: 20.0,
                  ),
                  SelectionContainer.disabled(
                      child: Text(I18n.of(context).pixel)),
                  Container(
                    width: 10.0,
                  ),
                  colorText("${data.width}x${data.height}", context)
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  SelectionContainer.disabled(
                      child: Text(I18n.of(context).total_view)),
                  Container(
                    width: 10.0,
                  ),
                  colorText(data.totalView.toString(), context),
                  Container(
                    width: 20.0,
                  ),
                  SelectionContainer.disabled(
                      child: Text(I18n.of(context).total_bookmark)),
                  Container(
                    width: 10.0,
                  ),
                  colorText("${data.totalBookmarks}", context)
                ],
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: 0,
            children: [
              if (data.illustAIType == 2)
                Text("${I18n.of(context).ai_generated}",
                    style: FluentTheme.of(context)
                        .typography
                        .caption!
                        .copyWith(color: FluentTheme.of(context).accentColor)),
              for (var f in data.tags) buildRow(context, f)
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SelectableHtml(
              data: data.caption.isEmpty ? "~" : data.caption,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SelectionContainer.disabled(
            child: HyperlinkButton(
              child: Text(
                I18n.of(context).view_comment,
                textAlign: TextAlign.center,
                style: FluentTheme.of(context).typography.body!,
              ),
              onPressed: () {
                Leader.push(context, CommentPage(id: data.id),
                    icon: Icon(FluentIcons.comment),
                    title: Text(I18n.of(context).view_comment));
              },
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(I18n.of(context).about_picture),
        ),
      ),
      buildRecom()
    ];
  }

  @override
  bool get wantKeepAlive => false;
}

class IllustItem extends StatelessWidget {
  final _flyoutController = FlyoutController();
  final _flyoutKey = GlobalKey();
  final int index;
  final Illusts data;
  final IllustItemsPage widget;
  final Widget icon;
  final Future Function() onMultiSavePressed;

  IllustItem(
    this.index,
    this.data,
    this.widget, {
    required this.icon,
    required this.onMultiSavePressed,
  });
  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      key: _flyoutKey,
      controller: _flyoutController,
      child: GestureDetector(
        child: IconButton(
          onPressed: () {
            Leader.push(
              context,
              PhotoZoomPage(
                index: index,
                illusts: data,
              ),
              icon: Icon(FluentIcons.picture),
              title: Text(I18n.of(context).illust_id + ': ${data.id}'),
            );
          },
          icon: icon,
        ),
        onSecondaryTapUp: (details) => _flyoutController.showFlyout(
          position: getPosition(context, _flyoutKey, details),
          barrierColor: Colors.black.withOpacity(0.1),
          builder: (context) => MenuFlyout(
            color: Colors.transparent,
            items: [
              if (data.metaPages.isNotEmpty)
                MenuFlyoutItem(
                  text: Text(I18n.of(context).muti_choice_save),
                  leading: Icon(
                    FluentIcons.save,
                  ),
                  onPressed: () async {
                    await onMultiSavePressed();
                    Navigator.of(context).pop();
                  },
                ),
              MenuFlyoutItem(
                leading: Icon(FluentIcons.save),
                onPressed: () async {
                  await saveStore.saveImage(data, index: index);
                  Navigator.of(context).pop();
                },
                text: Text(I18n.of(context).save),
              ),
              MenuFlyoutItem(
                text: Text(I18n.of(context).copymessage),
                leading: Icon(
                  FluentIcons.library,
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text:
                          'title:${data.title}\npainter:${data.user.name}\nillust id:${widget.id}'));
                  BotToast.showText(text: I18n.of(context).copied_to_clipboard);
                  Navigator.of(context).pop();
                },
              ),
              MenuFlyoutItem(
                text: Text(I18n.of(context).share),
                leading: Icon(
                  FluentIcons.share,
                ),
                onPressed: () async {
                  await Share.share(
                      "https://www.pixiv.net/artworks/${widget.id}");
                  Navigator.of(context).pop();
                },
              ),
              MenuFlyoutItem(
                leading: Icon(
                  FluentIcons.link,
                ),
                text: Text(I18n.of(context).link),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text: "https://www.pixiv.net/artworks/${widget.id}"));
                  BotToast.showText(text: I18n.of(context).copied_to_clipboard);
                  Navigator.of(context).pop();
                },
              ),
              MenuFlyoutItem(
                text: Text(I18n.of(context).ban),
                leading: Icon(FluentIcons.brightness),
                onPressed: () async {
                  await muteStore.insertBanIllusts(BanIllustIdPersist(
                      illustId: widget.id.toString(), name: data.title));
                  Navigator.of(context).pop();
                },
              ),
              MenuFlyoutItem(
                text: Text(I18n.of(context).report),
                leading: Icon(FluentIcons.report_document),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return ContentDialog(
                        title: Text(I18n.of(context).report),
                        content: Text(I18n.of(context).report_message),
                        actions: <Widget>[
                          HyperlinkButton(
                            child: Text(I18n.of(context).cancel),
                            onPressed: () {
                              Navigator.of(context).pop("CANCEL");
                            },
                          ),
                          HyperlinkButton(
                            child: Text(I18n.of(context).ok),
                            onPressed: () {
                              Navigator.of(context).pop("OK");
                            },
                          ),
                        ],
                      );
                    },
                  );
                  Navigator.of(context).pop();
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// 相关图片
class MoreItem extends StatelessWidget {
  final _flyoutController = FlyoutController();
  final _flyoutKey = GlobalKey();
  final int index;
  final List<IllustStore> list;
  final IllustAboutStore _aboutStore;

  MoreItem(
    this.index,
    this.list,
    this._aboutStore,
  );
  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _flyoutController,
      key: _flyoutKey,
      child: GestureDetector(
        child: IconButton(
          onPressed: () {
            Leader.push(
                context,
                PictureListPage(
                  iStores: list,
                  lightingStore: null,
                  store: list[index],
                ));
          },
          icon: PixivImage(
            _aboutStore.illusts[index].imageUrls.squareMedium,
            enableMemoryCache: false,
          ),
        ),
        onSecondaryTapUp: (details) => _flyoutController.showFlyout(
          position: getPosition(context, _flyoutKey, details),
          barrierColor: Colors.black.withOpacity(0.1),
          builder: (context) => MenuFlyout(
            color: Colors.transparent,
            items: [
              MenuFlyoutItem(
                text: Text(I18n.of(context).save),
                onPressed: () async {
                  await saveStore.saveImage(_aboutStore.illusts[index]);
                  Navigator.of(context).pop();
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}