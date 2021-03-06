// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2014 Birdie Developers (http://birdieapp.github.io)
 *
 * This software is licensed under the GNU General Public License
 * (version 3 or later). See the COPYING file in this distribution.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Ivo Nunes <ivoavnunes@gmail.com>
 *              Vasco Nunes <vascomfnunes@gmail.com>
 */

namespace Birdie {
#if HAVE_GRANITE
    public class Birdie : Granite.Application {
#else
    public class Birdie : Gtk.Application {
#endif
		private Gtk.Box m_box;
        public Widgets.UnifiedWindow m_window;
        public Widgets.TweetList home_list;
        public Widgets.TweetList mentions_list;
        public Widgets.TweetList dm_list;
        public Widgets.TweetList dm_sent_list;
        public Widgets.TweetList own_list;
        public Widgets.TweetList favorites;
        public Widgets.TweetList user_list;
        public Widgets.TweetList search_list;
        public Widgets.ListsView lists;
        public Widgets.TweetList list_list;

        private Gtk.MenuItem account_appmenu;
        private Gtk.MenuItem remove_appmenu;
        private Widgets.MenuPopOver menu;
        private List<Gtk.Widget> menu_tmp;

        private Gtk.ToolButton new_tweet;
        public Gtk.ToggleToolButton home;
        public Gtk.ToggleToolButton mentions;
        public Gtk.ToggleToolButton dm;
        public Gtk.ToggleToolButton profile;
        private Gtk.ToggleToolButton search;

        private Widgets.UserBox own_box_info;
        private Gtk.Box own_box;

        private Widgets.UserBox user_box_info;
        private Gtk.Box user_box;

        private Gtk.ScrolledWindow scrolled_home;
        private Gtk.ScrolledWindow scrolled_mentions;
        private Gtk.ScrolledWindow scrolled_dm;
        private Gtk.ScrolledWindow scrolled_dm_sent;
        private Gtk.ScrolledWindow scrolled_own;
        private Gtk.ScrolledWindow scrolled_favorites;
        private Gtk.ScrolledWindow scrolled_user;
        private Gtk.ScrolledWindow scrolled_lists;
        private Gtk.ScrolledWindow scrolled_search;
        private Gtk.ScrolledWindow scrolled_list;

        private Widgets.Welcome welcome;
        private Widgets.ErrorPage error_page;

        public Gtk.Stack notebook;
        private Widgets.Notebook notebook_dm;
        public Widgets.Notebook notebook_own;
        private Widgets.Notebook notebook_user;

        private Gtk.Spinner spinner;

        private GLib.List<Tweet> home_tmp;
        public GLib.List<string> list_members;

        public API api;
        public API new_api;

        public Utils.Notification notification;

        public string current_timeline;

        #if HAVE_LIBMESSAGINGMENU
        private Utils.Indicator indicator;
        #endif

        #if HAVE_LIBUNITY
        private Utils.Launcher launcher;
        #endif

        private Utils.StatusIcon statusIcon;

        private int unread_tweets;
        private int unread_mentions;
        private int unread_dm;

        private bool tweet_notification;
        private bool mention_notification;
        private bool dm_notification;
        private int update_interval;

        public Settings settings;

        public string user;
        private string search_term;
        private string list_id;
        private string list_owner;
        public bool adding_to_list;

        public bool initialized;
        private bool ready;
        private bool changing_tab;

        public SqliteDatabase db;

        private Cache cache;

        private User default_account;
        public int? default_account_id;

        private uint timerID_online;
        private uint timerID_offline;
        private DateTime timer_date_online;
        private DateTime timer_date_offline;

        private int limit_notifications;

        public static const OptionEntry[] app_options = {
            { "debug", 'd', 0, OptionArg.NONE, out Option.DEBUG, "Enable debug logging", null },
            { "start-hidden", 's', 0, OptionArg.NONE, out Option.START_HIDDEN, "Start hidden", null },
            { null }
        };

        private Gtk.MenuButton appmenu;

#if HAVE_GRANITE
        private Granite.Widgets.SearchBar search_entry;

        construct {
            program_name        = "Birdie";
            exec_name           = "birdie";
            build_version       = Constants.VERSION;
            app_years           = "2013-2014";
            app_icon            = "birdie";
            app_launcher        = "birdie.desktop";
            application_id      = "org.birdieapp.birdie";
            main_url            = "http://birdieapp.github.io/";
            bug_url             = "https://github.com/birdieapp/birdie/issues";
            help_url            = "https://github.com/birdieapp/birdie/wiki";
            translate_url       = "http://www.transifex.com/projects/p/birdie/";
            about_authors       = {"Ivo Nunes <ivo@elementaryos.org>", "Vasco Nunes <vascomfnunes@gmail.com>"};
            about_artists       = {"Daniel Foré <daniel@elementaryos.org>", "Mustapha Asbbar"};
            about_comments      = null;
            about_documenters   = {};
            about_translators   = null;
            about_license_type  = Gtk.License.GPL_3_0;
        }
#else
        private Gtk.SearchEntry search_entry;
#endif

        public Birdie () {
            GLib.Object(application_id: "org.birdie", flags: ApplicationFlags.HANDLES_OPEN);

            Intl.bindtextdomain ("birdie", Constants.DATADIR + "/locale");

            this.initialized = false;
            this.ready = false;
            this.changing_tab = false;
            this.adding_to_list = false;

            // create cache and db dirs if needed
            Utils.create_dir_with_parents ("/.cache/birdie/media");
            Utils.create_dir_with_parents ("/.local/share/birdie/avatars");

            // init database object
            this.db = new SqliteDatabase ();
            // init cache object
            this.cache = new Cache (this);
        }

        /*

        Activate method

        */

        public override void activate (){
            if (get_windows () == null) {
                Utils.Logger.initialize ("birdie");
                Utils.Logger.DisplayLevel = Utils.LogLevel.INFO;
                message ("Birdie version: %s", Constants.VERSION);
                var un = Posix.utsname ();
                message ("Kernel version: %s", (string) un.release);

                if (Option.DEBUG)
                    Utils.Logger.DisplayLevel = Utils.LogLevel.DEBUG;
                else
                    Utils.Logger.DisplayLevel = Utils.LogLevel.WARN;

                // settings
                this.settings = new Settings ("org.birdieapp.birdie");
                this.tweet_notification = settings.get_boolean ("tweet-notification");
                this.mention_notification = settings.get_boolean ("mention-notification");
                this.dm_notification = settings.get_boolean ("dm-notification");
                this.update_interval = settings.get_int ("update-interval");
                this.limit_notifications = settings.get_int ("limit-notifications");

                Gtk.Window.set_default_icon_name ("birdie");
                this.m_window = new Widgets.UnifiedWindow ();

                this.m_window.set_default_size (425, 500);
                this.m_window.set_size_request (425, 50);
                this.m_window.set_application (this);

                // restore main window size and position
                this.m_window.opening_x = settings.get_int ("opening-x");
                this.m_window.opening_y = settings.get_int ("opening-y");
                this.m_window.window_width = settings.get_int ("window-width");
                this.m_window.window_height = settings.get_int ("window-height");
                this.m_window.restore_window ();

                #if HAVE_LIBMESSAGINGMENU
                this.indicator = new Utils.Indicator (this);
                #endif

                #if HAVE_LIBUNITY
                this.launcher = new Utils.Launcher (this);
                #endif

                if (settings.get_boolean ("status-icon") && !Utils.is_gnome ())
                    this.statusIcon = new Utils.StatusIcon (this);

                // initialize notifications
                this.notification = new Utils.Notification ();
                this.notification.init ();

                this.unread_tweets = 0;
                this.unread_mentions = 0;
                this.unread_dm = 0;

                this.m_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

                this.new_tweet = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR), _("New Tweet"));
                new_tweet.set_tooltip_text (_("New Tweet"));

                new_tweet.clicked.connect (() => {
                    bool is_dm = false;

                    if (this.current_timeline == "dm")
                        is_dm = true;

                    Widgets.TweetDialog dialog = new Widgets.TweetDialog (this, "", "", is_dm);
                    dialog.show_all ();
                });

                new_tweet.set_sensitive (false);
                this.m_window.header.pack_start (new_tweet);

                Gtk.Box centered_toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

                this.home = new Gtk.ToggleToolButton ();
                this.home.set_icon_widget (new Gtk.Image.from_icon_name ("twitter-home", Gtk.IconSize.LARGE_TOOLBAR));
                home.set_tooltip_text (_("Home"));
                home.set_label (_("Home"));
                home.toggled.connect (() => {
                    if (!this.changing_tab)
                        this.switch_timeline ("home");
                });
                this.home.set_sensitive (false);
                centered_toolbar.add (home);

                this.mentions = new Gtk.ToggleToolButton ();
                this.mentions.set_icon_widget (new Gtk.Image.from_icon_name ("twitter-mentions", Gtk.IconSize.LARGE_TOOLBAR));
                mentions.set_tooltip_text (_("Mentions"));
                mentions.set_label (_("Mentions"));
                mentions.toggled.connect (() => {
                    if (!this.changing_tab)
                        this.switch_timeline ("mentions");
                });
                this.mentions.set_sensitive (false);
                centered_toolbar.add (mentions);

                this.dm = new Gtk.ToggleToolButton ();
                this.dm.set_icon_widget (new Gtk.Image.from_icon_name ("twitter-dm", Gtk.IconSize.LARGE_TOOLBAR));
                dm.set_tooltip_text (_("Direct Messages"));
                dm.set_label (_("Direct Messages"));
                dm.toggled.connect (() => {
                    if (!this.changing_tab)
                        this.switch_timeline ("dm");
                });
                this.dm.set_sensitive (false);
                centered_toolbar.add (dm);

                this.profile = new Gtk.ToggleToolButton ();
                this.profile.set_icon_widget (new Gtk.Image.from_icon_name ("twitter-profile", Gtk.IconSize.LARGE_TOOLBAR));
                profile.set_tooltip_text (_("Profile"));
                profile.set_label (_("Profile"));

                profile.toggled.connect (() => {
                    if (!this.changing_tab)
                        this.switch_timeline ("own");
                });
                this.profile.set_sensitive (false);
                centered_toolbar.add (profile);

                // create the searchentry
#if HAVE_GRANITE
                search_entry = new Granite.Widgets.SearchBar (_("Search"));
#else
                search_entry = new Gtk.SearchEntry ();
#endif

                search_entry.activate.connect (() => {
                    this.search_term = ((Gtk.Entry)search_entry).get_text ();
                    this.show_search.begin ();
                });

                // create the searchbar
                Gtk.SearchBar search_bar = new Gtk.SearchBar ();
                search_bar.add (search_entry);
                this.m_box.pack_start (search_bar, false, false, 0);

                this.search = new Gtk.ToggleToolButton ();
                this.search.set_icon_widget (new Gtk.Image.from_icon_name ("twitter-search", Gtk.IconSize.LARGE_TOOLBAR));
                search.set_tooltip_text (_("Search"));
                search.set_label (_("Search"));

                this.search.bind_property("active", search_bar, "search-mode-enabled", GLib.BindingFlags.BIDIRECTIONAL);
                this.search.set_sensitive (false);
                centered_toolbar.add (search);

                this.m_window.header.set_custom_title (centered_toolbar);

                menu = new Widgets.MenuPopOver ();
                this.account_appmenu = new Gtk.MenuItem.with_label (_("Add Account"));
                account_appmenu.activate.connect (() => {
                    this.switch_timeline ("welcome");
                });
                this.account_appmenu.set_sensitive (false);

                this.remove_appmenu = new Gtk.MenuItem.with_label (_("Remove Account"));
                remove_appmenu.activate.connect (() => {
                    // confirm remove account
                    Widgets.AlertDialog confirm = new Widgets.AlertDialog (this.m_window,
                        Gtk.MessageType.QUESTION, _("Remove this account?"),
                        _("Remove"), _("Cancel"));
                    Gtk.ResponseType response = confirm.run ();
                    if (response == Gtk.ResponseType.OK) {
                        var appmenu_icon = new Gtk.Image.from_icon_name ("application-menu", Gtk.IconSize.MENU);
                        appmenu_icon.show ();
                        this.appmenu.remove(appmenu.get_child());
                        this.appmenu.add(appmenu_icon);
                        this.set_widgets_sensitive (false);
                        this.db.remove_account (this.default_account);
                        User account = this.db.get_default_account ();
                        this.set_user_menu ();

                        if (account == null) {
                            this.init_api ();
                            this.switch_timeline ("welcome");
                        } else {
                            this.switch_account (account);
                        }
                    }
                });
                this.remove_appmenu.set_sensitive (false);

                var about_appmenu = new Gtk.MenuItem.with_label (_("About"));
                about_appmenu.activate.connect (() => {
#if HAVE_GRANITE
                    show_about (this.m_window);
#else
                    Gtk.AboutDialog dialog = new Gtk.AboutDialog ();
                    dialog.set_destroy_with_parent (true);
                    dialog.set_transient_for (this.m_window);
                    dialog.set_modal (true);

                    dialog.artists = {"Daniel Foré", "Mustapha Asbbar"};
                    dialog.authors = {"Ivo Nunes", "Vasco Nunes"};
                    dialog.documenters = null;
                    dialog.translator_credits = null;

                    dialog.logo_icon_name = "birdie";
                    dialog.program_name = "Birdie";
                    dialog.comments = Constants.COMMENT;
                    dialog.copyright = "Copyright © 2013-2014 Ivo Nunes / Vasco Nunes";
                    dialog.version = Constants.VERSION;

                    dialog.license_type = Gtk.License.GPL_3_0;
                    dialog.wrap_license = true;

                    dialog.website = "http://birdieapp.github.io/";
                    dialog.website_label = "Birdie Website";

                    dialog.response.connect ((response_id) => {
                        if (response_id == Gtk.ResponseType.CANCEL || response_id == Gtk.ResponseType.DELETE_EVENT) {
                            dialog.destroy ();
                        }
                    });

                    dialog.present ();
#endif
                });
                var donate_appmenu = new Gtk.MenuItem.with_label (_("Donate"));
                donate_appmenu.activate.connect (() => {
                    try {
                        GLib.Process.spawn_command_line_async ("xdg-open http://birdieapp.github.io/donate.html");
                    } catch (Error e) {
                    }
                });
                var quit_appmenu = new Gtk.MenuItem.with_label (_("Quit"));
                quit_appmenu.activate.connect (() => {
                    // save window size and position
                    int x, y, w, h;
                    m_window.get_position (out x, out y);
                    m_window.get_size (out w, out h);
                    this.settings.set_int ("opening-x", x);
                    this.settings.set_int ("opening-y", y);
                    this.settings.set_int ("window-width", w);
                    this.settings.set_int ("window-height", h);

                    // destroy notifications
                    this.notification.uninit ();

                    m_window.destroy ();
                });
                menu.add (account_appmenu);
                menu.add (remove_appmenu);

                if (!Utils.is_gnome ()) {
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (about_appmenu);
                    menu.add (donate_appmenu);
                    menu.add (quit_appmenu);
                }

                this.appmenu = new Gtk.MenuButton ();
                this.appmenu.set_relief (Gtk.ReliefStyle.NONE);
                this.appmenu.set_popup (menu);

                if (Utils.is_gnome ()) {
                    var action = new GLib.SimpleAction ("about", null);
                    action.activate.connect (() => { about_appmenu.activate (); });
                    add_action (action);
                    action = new GLib.SimpleAction ("donate", null);
                    action.activate.connect (() => { donate_appmenu.activate (); });
                    add_action (action);
                    action = new GLib.SimpleAction ("quit", null);
                    action.activate.connect (() => { quit_appmenu.activate (); });
                    add_action (action);

                    var menu = new GLib.Menu ();

                    menu.append (_("About"), "app.about");
                    menu.append (_("Donate"), "app.donate");
                    menu.append (_("Quit"), "app.quit");

                    set_app_menu (menu);
                }

                this.m_window.header.pack_end (appmenu);

                /*==========  tweets lists  ==========*/

                this.home_list = new Widgets.TweetList ();
                this.mentions_list = new Widgets.TweetList ();
                this.dm_list = new Widgets.TweetList ();
                this.dm_sent_list = new Widgets.TweetList ();
                this.own_list = new Widgets.TweetList ();
                this.user_list = new Widgets.TweetList ();
                this.favorites = new Widgets.TweetList ();
                this.lists = new Widgets.ListsView(this);
                this.list_list = new Widgets.TweetList ();
                this.search_list = new Widgets.TweetList ();

                /*==========  older statuses  ==========*/

                this.home_list.more_button.button.clicked.connect (get_older_tweets);
                this.home_list.load_more = true;
                this.mentions_list.more_button.button.clicked.connect (get_older_mentions);
                this.mentions_list.load_more = true;
                this.search_list.more_button.button.clicked.connect (get_older_search);
                this.search_list.load_more = true;

                /*==========  scrolled widgets  ==========*/

                this.scrolled_home = new Gtk.ScrolledWindow (null, null);
                this.scrolled_home.add_with_viewport (home_list);

                this.scrolled_mentions = new Gtk.ScrolledWindow (null, null);
                this.scrolled_mentions.add_with_viewport (mentions_list);

                this.scrolled_dm = new Gtk.ScrolledWindow (null, null);
                this.scrolled_dm.add_with_viewport (dm_list);
                this.scrolled_dm_sent = new Gtk.ScrolledWindow (null, null);
                this.scrolled_dm_sent.add_with_viewport (dm_sent_list);

                this.scrolled_own = new Gtk.ScrolledWindow (null, null);

                this.scrolled_favorites = new Gtk.ScrolledWindow (null, null);
                this.scrolled_lists = new Gtk.ScrolledWindow (null, null);
                this.scrolled_lists.add_with_viewport (this.lists);

                this.scrolled_user = new Gtk.ScrolledWindow (null, null);
                this.scrolled_user.add_with_viewport (user_list);

                this.scrolled_list = new Gtk.ScrolledWindow (null, null);
                this.scrolled_list.add_with_viewport (list_list);

                this.scrolled_search = new Gtk.ScrolledWindow (null, null);
                this.scrolled_search.add_with_viewport (search_list);

                this.welcome = new Widgets.Welcome (this);
                this.error_page = new Widgets.ErrorPage (this);

                this.notebook_dm = new Widgets.Notebook ();
                this.notebook_dm.append_page (this.scrolled_dm, new Gtk.Label (_("Received")));
                this.notebook_dm.append_page (this.scrolled_dm_sent, new Gtk.Label (_("Sent")));

                this.notebook = new Gtk.Stack ();
                this.notebook.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

                this.spinner = new Gtk.Spinner ();
                this.spinner.set_size_request (32, 32);
                this.spinner.start ();

                Gtk.Box spinner_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                spinner_box.pack_start (new Gtk.Label (""), true, true, 0);
                spinner_box.pack_start (this.spinner, false, false, 0);
                spinner_box.pack_start (new Gtk.Label (""), true, true, 0);

                this.init_api ();

                this.own_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                this.own_box_info = new Widgets.UserBox ();
                this.own_box.pack_start (this.own_box_info, false, false, 0);
                this.scrolled_favorites.add_with_viewport (this.favorites);
                this.scrolled_own.add_with_viewport (this.own_list);

                this.notebook_own = new Widgets.Notebook ();
                this.notebook_own.append_page (this.scrolled_own, new Gtk.Label (_("Timeline")));
                this.notebook_own.append_page (this.scrolled_favorites, new Gtk.Label (_("Favorites")));
                this.notebook_own.append_page (this.scrolled_lists, new Gtk.Label (_("Lists")));
                this.own_box.pack_start (this.notebook_own, true, true, 0);

                this.user_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                this.user_box_info = new Widgets.UserBox ();
                this.notebook_user = new Widgets.Notebook ();
                this.notebook_user.set_tabs (false);
                this.notebook_user.append_page (this.scrolled_user, new Gtk.Label (_("Timeline")));
                this.user_box.pack_start (this.user_box_info, false, false, 0);

                // separator
                this.user_box.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);
                this.user_box.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);

                this.user_box.pack_start (this.notebook_user, true, true, 0);

                this.notebook.add_named (spinner_box, "loading");
                this.notebook.add_named (this.welcome, "welcome");
                this.notebook.add_named (this.scrolled_home, "home");
                this.notebook.add_named (this.scrolled_mentions, "mentions");
                this.notebook.add_named (this.notebook_dm, "dm");
                this.notebook.add_named (this.own_box, "own");
                this.notebook.add_named (this.user_box, "user");
                this.notebook.add_named (this.scrolled_list, "list");
                this.notebook.add_named (this.scrolled_search, "search");
                this.notebook.add_named (this.error_page, "error");

                this.m_box.pack_start (this.notebook, true, true, 0);
                this.m_window.add(this.m_box);

                this.m_window.focus_in_event.connect ((w, e) => {
                    #if HAVE_LIBUNITY
                    if (get_total_unread () > 0)
                        this.launcher.clean_launcher_count ();
                    #endif
                    switch (this.current_timeline) {
                        case "home":
                            clean_tweets_indicator ();
                            break;
                        case "mentions":
                            clean_mentions_indicator ();
                            break;
                        case "dm":
                            clean_dm_indicator ();
                            break;
                    }

                    return true;
                });

                this.m_window.show_all ();

                if (Option.START_HIDDEN) {
                    this.m_window.hide ();
                }

                this.default_account = this.db.get_default_account ();
                this.default_account_id = this.db.get_account_id ();

                if (this.default_account == null) {
                    this.switch_timeline ("welcome");
                } else {
                    this.api.token = this.default_account.token;
                    this.api.token_secret = this.default_account.token_secret;
                    this.init.begin ();
                }
            } else {
                this.m_window.show_all ();
                #if HAVE_LIBUNITY
                if (get_total_unread () > 0)
                    this.launcher.clean_launcher_count ();
                #endif
                while (Gtk.events_pending ())
                    Gtk.main_iteration ();

                switch (this.current_timeline) {
                    case "home":
                        clean_tweets_indicator ();
                        break;
                    case "mentions":
                        clean_mentions_indicator ();
                        break;
                    case "dm":
                        clean_dm_indicator ();
                        break;
                }
                this.m_window.present ();
                check_timeout_health ();
            }
        }

        protected override void open (File[] files, string hint) {
            foreach (File file in files) {
                string url = file.get_uri ();

                if ("birdie://user/" in url) {
                    user = url.replace ("birdie://user/", "");
                    if ("/" in user)
                        user = user.replace ("/", "");
                    if ("@" in user)
                        user = user.replace ("@", "");

                    this.show_user.begin ();
                } else if ("birdie://search/" in url) {
                    search_term = url.replace ("birdie://search/", "");
                    if ("/" in search_term)
                       search_term = search_term.replace ("/", "");
                    this.show_search.begin ();
                } else if ("birdie://list/" in url) {
                    list_id = url.replace ("birdie://list/", "");

                    list_owner = list_id.split("/")[0];
                    list_owner = list_owner.replace("@", "");
                    list_id = list_id.split("/")[1];

                    if ("/" in list_id)
                       list_id = search_term.replace ("/", "");

                    if (this.adding_to_list) {
                        if (list_owner == this.api.account.screen_name) {
                            this.api.add_to_list (list_id, user);
                            this.switch_timeline ("user");
                        } else {
                            Gtk.MessageDialog msg = new Gtk.MessageDialog (this.m_window, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, _("You must select a list you own."));
			                msg.response.connect (() => {
			                    msg.destroy();
		                    });
		                    msg.show ();
                        }
                    } else {
                        this.show_list.begin ();
                    }
                }
            }
            activate ();
        }

        public void new_tweet_keybinding () {
            Widgets.TweetDialog dialog = new Widgets.TweetDialog (this, "", "", false);
            dialog.show_all ();
        }

        public async void request () throws ThreadError {
            SourceFunc callback = request.callback;

            ThreadFunc<void*> run = () => {

                this.new_api = new Twitter (this);

                Idle.add (() => {
                    var window_active = this.home.get_sensitive ();
                    this.set_widgets_sensitive (false);

                    var light_window = new Widgets.LightWindow (false);
                    var web_view = new WebKit.WebView ();
                    web_view.document_load_finished.connect (() => {
                        web_view.execute_script ("oldtitle=document.title;document.title=document.documentElement.innerHTML;");
                        var html = web_view.get_main_frame ().get_title ();
                        web_view.execute_script ("document.title=oldtitle;");

                        if ("<code>" in html) {
                            var pin = html.split ("<code>");
                            pin = pin[1].split ("</code>");
                            light_window.destroy ();

                            new Thread<void*> (null, () => {
                                this.switch_timeline ("loading");

                                int code = this.new_api.get_tokens (pin[0]);

                                if (code == 0) {
                                    Idle.add (() => {
                                        var appmenu_icon = new Gtk.Image.from_icon_name ("application-menu", Gtk.IconSize.MENU);
                                        appmenu_icon.show ();
                                        this.appmenu.remove(appmenu.get_child());
                                        this.appmenu.add(appmenu_icon);
                                        this.set_widgets_sensitive (false);
                                        return false;
                                    });

                                    this.api = this.new_api;
                                    this.init.begin ();
                                } else {
                                    this.switch_timeline ("welcome");
                                }

                                return null;
                            });
                        }
                    });
                    light_window.destroy.connect (() => {
                        this.set_widgets_sensitive (window_active);
                    });
                    web_view.load_uri (this.new_api.get_request ());
                    var scrolled_webview = new Gtk.ScrolledWindow (null, null);
                    scrolled_webview.add_with_viewport (web_view);
                    light_window.set_title (_("Sign in"));
                    light_window.add (scrolled_webview);
                    light_window.set_transient_for (this.m_window);
                    light_window.set_modal (true);
                    light_window.set_size_request (600, 600);
                    light_window.show_all ();

                    return false;
                });
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            yield;
        }

        /*

        initializations methods

        */

        private void init_api () {
            this.api = null;
            this.api = new Twitter (this);
        }

        public async void init () throws ThreadError {
            SourceFunc callback = init.callback;

            Idle.add (() => {
                this.appmenu.set_sensitive (false);
                return false;
            });

            this.switch_timeline ("loading");

            if (this.check_internet_connection ()) {

                ThreadFunc<void*> run = () => {

                    if (this.ready)
                        this.ready = false;

                    // initialize the api
                    this.api.auth ();
                    this.api.get_account ();

                    // get the current account
                    this.default_account = this.db.get_default_account ();
                    this.default_account_id = this.db.get_account_id ();

                    this.home_list.clear ();
                    this.mentions_list.clear ();
                    this.dm_list.clear ();
                    this.dm_sent_list.clear ();
                    this.own_list.clear ();
                    this.user_list.clear ();
                    this.favorites.clear ();
                    this.lists.clear ();

                    // get cached tweets, avatars and media

                    this.cache.set_default_account (this.default_account_id);

                    this.cache.load_cached_tweets ("tweets", this.home_list);
                    this.cache.load_cached_tweets ("mentions", this.mentions_list);
                    this.cache.load_cached_tweets ("dm_inbox", this.dm_list);
                    this.cache.load_cached_tweets ("dm_outbox", this.dm_sent_list);
                    this.cache.load_cached_tweets ("own", this.own_list);
                    this.cache.load_cached_tweets ("favorites", this.favorites);

                    // get fresh timelines

                    this.api.get_home_timeline ();
                    this.api.get_mentions_timeline ();
                    this.api.get_direct_messages ();
                    this.api.get_direct_messages_sent ();
                    this.api.get_own_timeline ();
                    this.api.get_favorites ();
                    this.api.get_lists ();

                    if (this.initialized) {
                        this.own_box_info.update (this.api.account);
                        this.user_box_info.update (this.api.account);
                        this.remove_timeouts ();
                    } else {
                        this.own_box_info.init (this.api.account, this);
                        this.user_box_info.init (this.api.account, this);
                    }

                    Media.get_userbox_avatar (this.own_box_info, true);
                    this.db.update_account (this.api.account);

                    this.set_user_menu ();
                    this.set_account_avatar (this.api.account);

                    this.initialized = true;
                    this.appmenu.set_sensitive (true);

                    Idle.add((owned) callback);
                    return null;
                };

                Thread.create<void*>(run, false);

                // Wait for background thread to schedule our callback
                yield;
            } else {
                this.switch_timeline ("error");
            }
        }

        /*

        Setup user accounts menu

        */

        private void set_user_menu () {
            this.menu_tmp.foreach ((w) => {
                this.menu.remove (w);
                this.menu_tmp.remove (w);
            });

            // get all accounts
            List<User?> all_accounts = new List<User?> ();
            all_accounts = this.db.get_all_accounts ();

            if (all_accounts.length () > 0) {
                var sep = new Gtk.SeparatorMenuItem ();
                this.menu_tmp.prepend (sep);
                this.menu.prepend (sep);
            }

            foreach (var account in all_accounts) {
                Gtk.Image avatar_image_menu = new Gtk.Image.from_file (Environment.get_home_dir () +
                    "/.local/share/birdie/avatars/" + account.profile_image_file);
                Gtk.ImageMenuItem account_menu_item = new Gtk.ImageMenuItem.with_label (account.name +
                    "\n@" + account.screen_name);

                account_menu_item.activate.connect (() => {
                    switch_account (account);
                });

                foreach (var child in account_menu_item.get_children ()) {
                    if (child is Gtk.Label)
                        ((Gtk.Label)child).set_markup ("<b>" + account.name +
                            "</b>\n@" + account.screen_name);
                }

                account_menu_item.set_image (avatar_image_menu);
                account_menu_item.set_always_show_image (true);

                this.menu_tmp.prepend (account_menu_item);
                this.menu.prepend (account_menu_item);
            }

            this.menu.show_all ();
        }

        private void set_account_avatar (User account) {
            Gtk.Image avatar_image = null;

            try {
                Gdk.Pixbuf avatar_pixbuf = new Gdk.Pixbuf.from_file_at_scale (Environment.get_home_dir () +
                    "/.local/share/birdie/avatars/" + account.profile_image_file, 24, 24, true);
                avatar_image = new Gtk.Image.from_pixbuf (avatar_pixbuf);
            } catch (Error e) {
                avatar_image = new Gtk.Image.from_icon_name ("application-menu", Gtk.IconSize.MENU);
                debug ("Error creating pixbuf: " + e.message);
            }

            avatar_image.show ();
            this.appmenu.remove(appmenu.get_child());
            this.appmenu.add(avatar_image);
        }

        private void switch_account (User account) {
            this.set_account_avatar (account);

            this.search_list.clear ();
            this.search_entry.text = "";

            this.db.set_default_account (account);
            this.default_account = account;
            this.default_account_id = this.db.get_account_id ();

            this.set_widgets_sensitive (false);

            this.init_api ();
            switch_timeline ("loading");

            this.api.token = this.default_account.token;
            this.api.token_secret = this.default_account.token_secret;
            this.init.begin ();
        }

        public void set_widgets_sensitive (bool sensitive) {
            this.new_tweet.set_sensitive (sensitive);
            this.home.set_sensitive (sensitive);
            this.mentions.set_sensitive (sensitive);
            this.dm.set_sensitive (sensitive);
            this.profile.set_sensitive (sensitive);
            this.search.set_sensitive (sensitive);
            this.account_appmenu.set_sensitive (sensitive);
            this.remove_appmenu.set_sensitive (sensitive);
        }

        public void switch_timeline (string new_timeline) {
            Idle.add( () => {
                this.changing_tab = true;

                bool active = false;

                if (this.adding_to_list) {
                    this.notebook_own.set_tabs (true);
                    this.notebook_own.page = 0;
                    this.adding_to_list = false;
                }

                if (this.current_timeline == new_timeline)
                    active = true;

                switch (current_timeline) {
                    case "home":
                        this.home.set_active (active);
                        break;
                    case "mentions":
                        this.mentions.set_active (active);
                        break;
                    case "dm":
                        this.dm.set_active (active);
                        break;
                    case "own":
                        this.profile.set_active (active);
                        break;
                    case "search":
                        this.search.set_active (active);
                        break;
                }

                this.changing_tab = false;
                this.set_widgets_sensitive (true);

                switch (new_timeline) {
                    case "loading":
                        this.spinner.start ();
                        break;
                    case "welcome":
                        break;
                    case "home":
                        if (current_timeline == "home") this.scrolled_home.get_vadjustment().set_value(0);
                        this.clean_tweets_indicator ();
                        break;
                    case "mentions":
                        if (current_timeline == "mentions") this.scrolled_mentions.get_vadjustment().set_value(0);
                        this.clean_mentions_indicator ();
                        break;
                    case "dm":
                        if (current_timeline == "dm") this.scrolled_dm.get_vadjustment().set_value(0);
                        this.clean_dm_indicator ();
                        break;
                    case "own":
                        if (current_timeline == "own") this.scrolled_own.get_vadjustment().set_value(0);
                        break;
                    case "user":
                        this.scrolled_user.get_vadjustment().set_value(0);
                        break;
                    case "list":
                        break;
                    case "search":
                        this.search.set_active (true);
                        break;
                    case "error":
                        this.set_widgets_sensitive (false);
                        break;
                }

                this.notebook.set_visible_child_name (new_timeline);
                this.current_timeline = new_timeline;

                return false;
            });
        }

        /*

        GLib timeout methods

        */

        private void check_timeout_health () {
        	if (Utils.timeout_is_dead (this.update_interval, this.timer_date_offline)) {
        		debug ("Offline timeout died.");
        		GLib.Source.remove (this.timerID_offline);
        		add_timeout_offline ();
        	}

        	if (Utils.timeout_is_dead (this.update_interval, this.timer_date_online)) {
        		debug ("Online timeout died.");
        		GLib.Source.remove (this.timerID_online);
        		add_timeout_online ();
        	}
        }

        public void add_timeout_offline () {
        	this.timer_date_offline = new DateTime.now_utc ();

            this.timerID_offline = GLib.Timeout.add_seconds (60, () => {
                this.update_dates.begin ();
                return true;
            });
        }

        public void add_timeout_online () {
        	this.timer_date_online = new DateTime.now_utc ();

            this.timerID_online = GLib.Timeout.add_seconds (this.update_interval * 60, () => {
                new Thread<void*> (null, this.update_timelines);
                return true;
             });
        }

        private void remove_timeouts () {
            GLib.Source.remove (this.timerID_offline);
            GLib.Source.remove (this.timerID_online);
        }

        /*

        Update methods

        */

        public void* update_timelines () {
            if (this.check_internet_connection ()) {
                this.api.get_home_timeline ();
                this.api.get_mentions_timeline ();
                this.api.get_direct_messages ();
            } else {
                this.switch_timeline ("error");
            }
            return null;
        }

        public void update_home_ui () {
            string notify_header = "";
            string notify_text = "";
            string avatar = "";

            Idle.add (() => {
                this.home_tmp.foreach ((tweet) => {
                    this.home_list.remove (tweet);
                    this.home_tmp.remove (tweet);
                });

                this.api.home_timeline.foreach ((tweet) => {
                    this.home_list.append (tweet, this);
                    this.db.add_user.begin (tweet.user_screen_name,
                        tweet.user_name, this.default_account_id);

                    foreach (string hashtag in Utils.get_hashtags_list(tweet.text)) {
                        if (hashtag.has_prefix("#"))
                            this.db.add_hashtag.begin (hashtag.replace ("#", ""), this.default_account_id);
                    }

                    if (this.tweet_notification) {
                        if ((this.api.account.screen_name != tweet.user_screen_name) &&
                                this.api.home_timeline.length () <= this.limit_notifications) {
                            notify_header = _("New tweet from") + " " + tweet.user_screen_name;
                            notify_text = tweet.text;
                            avatar = tweet.profile_image_file;
                        }

                        if (this.api.account.screen_name != tweet.user_screen_name)
                            this.unread_tweets++;

                        if (this.tweet_notification && this.api.home_timeline.length () <=
                            this.limit_notifications  &&
                            this.api.home_timeline.length () > 0 &&
                            (this.api.account.screen_name != tweet.user_screen_name)) {
                                this.notification.notify (this,
                                                          notify_header,
                                                          notify_text,
                                                          "home",
                                                          false,
                                                          Environment.get_home_dir () + "/.cache/birdie/" + avatar);
                        }
                    }
                });

                if (this.tweet_notification && this.api.home_timeline.length () > this.limit_notifications && this.unread_tweets > 0) {
                    this.notification.notify (this, this.unread_tweets.to_string () + " " + _("new tweets"));
                }

                if (this.tweet_notification && get_total_unread () > 0) {
                    #if HAVE_LIBMESSAGINGMENU
                    this.indicator.update_tweets_indicator (this.unread_tweets);
                    #endif
                    #if HAVE_LIBUNITY
                    this.launcher.set_count (get_total_unread ());
                    #endif
                }

                if (!this.ready) {
                    get_all_avatars.begin ();

                    this.ready = true;

                    this.add_timeout_online ();
                    this.add_timeout_offline ();

                    this.current_timeline = "home";
                    this.switch_timeline ("home");
                    this.set_widgets_sensitive (true);
                } else {
                    Media.get_avatar (this.home_list);
                }
                this.spinner.stop ();
                return false;
            });
        }

        public async void get_all_avatars () throws ThreadError {
            SourceFunc callback = get_all_avatars.callback;

            ThreadFunc<void*> run = () => {
                Media.get_avatar (this.home_list);
                Media.get_avatar (this.mentions_list);
                Media.get_avatar (this.dm_list);
                Media.get_avatar (this.dm_sent_list);
                Media.get_avatar (this.own_list);
                Media.get_avatar (this.favorites);
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            yield;
        }

        public void update_dm_sent_ui () {
            Idle.add (() => {
                this.api.dm_sent_timeline.foreach ((tweet) => {
                    this.dm_sent_list.append(tweet, this);
                });

                if (this.ready)
                    Media.get_avatar (this.dm_sent_list);

                return false;
            });
        }

        public void update_own_timeline_ui () {
            Idle.add (() => {
                this.api.own_timeline.foreach ((tweet) => {
                    this.own_list.append (tweet, this);
                });

                if (this.ready)
                    Media.get_avatar (this.own_list);

                return false;
            });
        }

        public void update_favorites_ui () {
            Idle.add (() => {
                this.api.favorites.foreach ((tweet) => {
                    this.favorites.append(tweet, this);
                    this.db.add_user.begin (tweet.user_screen_name,
                        tweet.user_name, this.default_account_id);
                });

                if (this.ready)
                    Media.get_avatar (this.favorites);

                return false;
            });
        }

        public void update_mentions_ui () {
            bool new_mentions = false;
            string notify_header = "";
            string notify_text = "";
            string avatar = "";

            Idle.add (() => {
                this.api.mentions_timeline.foreach ((tweet) => {
                    this.mentions_list.append (tweet, this);
                    this.db.add_user.begin (tweet.user_screen_name,
                            tweet.user_name, this.default_account_id);
                        if (this.mention_notification) {
                            if ((this.api.account.screen_name != tweet.user_screen_name) &&
                                    this.api.mentions_timeline.length () <= this.limit_notifications) {
                                notify_header = _("New mention from") + " " + tweet.user_screen_name;
                                notify_text = tweet.text;
                                avatar = tweet.profile_image_file;
                            }
                            if (this.api.account.screen_name != tweet.user_screen_name) {
                                this.unread_mentions++;
                                new_mentions = true;
                            }

                        if (this.tweet_notification && this.api.mentions_timeline.length () <=
                            this.limit_notifications &&
                            this.api.mentions_timeline.length () > 0 &&
                            (this.api.account.screen_name != tweet.user_screen_name)) {
                                this.notification.notify (this, notify_header, notify_text, "mentions", false, Environment.get_home_dir () + "/.cache/birdie/" + avatar);
                        }
                    }
                });

                if (this.mention_notification && this.api.mentions_timeline.length () > this.limit_notifications) {
                    this.notification.notify (this, this.unread_mentions.to_string () + " " + _("new mentions"), "", "mentions");
                }

                if (this.mention_notification && new_mentions) {
                    #if HAVE_LIBMESSAGINGMENU
                    this.indicator.update_mentions_indicator (this.unread_mentions);
                    #endif
                    #if HAVE_LIBUNITY
                    this.launcher.set_count (get_total_unread ());
                    #endif
                }

                if (this.ready)
                    Media.get_avatar (this.mentions_list);

                return false;
            });
        }

        public void update_dm_ui () {
            bool new_dms = false;
            string notify_header = "";
            string notify_text = "";
            string avatar = "";

            Idle.add (() => {
                this.api.dm_timeline.foreach ((tweet) => {
                    this.dm_list.append (tweet, this);
                    this.db.add_user.begin (tweet.user_screen_name,
                            tweet.user_name, this.default_account_id);
                    if (this.dm_notification) {
                        if ((this.api.account.screen_name !=
                                    tweet.user_screen_name) &&
                                    this.api.dm_timeline.length () <=
                                    this.limit_notifications) {
                            notify_header = _("New direct message from") + " " + tweet.user_screen_name;
                            notify_text = tweet.text;
                            avatar = tweet.profile_image_file;
                        }
                        if (this.api.account.screen_name != tweet.user_screen_name) {
                            this.unread_dm++;
                            new_dms = true;
                        }

                        if (this.tweet_notification && this.api.dm_timeline.length () <=
                            this.limit_notifications  &&
                            this.api.dm_timeline.length () > 0 &&
                            (this.api.account.screen_name != tweet.user_screen_name)) {
                                this.notification.notify (this, notify_header, notify_text, "dm", true, Environment.get_home_dir () + "/.cache/birdie/" + avatar);
                        }
                    }
                });


                if (this.ready)
                    Media.get_avatar (this.dm_list);

                if (this.dm_notification && this.api.dm_timeline.length () > this.limit_notifications) {
                    this.notification.notify (this, this.unread_dm.to_string () + " " + _("new direct messages"), "", "dm", true);
                }

                if (this.dm_notification && new_dms) {
                    #if HAVE_LIBMESSAGINGMENU
                    this.indicator.update_dm_indicator (this.unread_dm);
                    #endif
                    #if HAVE_LIBUNITY
                    this.launcher.set_count (get_total_unread ());
                    #endif
                }

                return false;
            });
        }

        public async void update_dates () throws ThreadError {
            SourceFunc callback = update_dates.callback;

            ThreadFunc<void*> run = () => {
                this.home_list.update_date ();
                this.mentions_list.update_date ();
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            yield;
        }

        private int get_total_unread () {
            return this.unread_tweets + this.unread_mentions + this.unread_dm;
        }

        /*

        Older statuses

        */

        private void get_older_tweets ()  {
            if (this.check_internet_connection ()) {
                this.api.get_older_home_timeline ();
            } else {
                this.switch_timeline ("error");
            }
        }

        public void update_older_home_ui () {
            Idle.add (() => {
                this.home_tmp.foreach ((tweet) => {
                    this.home_list.remove (tweet);
                    this.home_tmp.remove (tweet);
                });

                this.api.home_timeline.foreach ((tweet) => {
                    this.home_list.prepend (tweet, this);
                    this.db.add_user.begin (tweet.user_screen_name,
                        tweet.user_name, this.default_account_id);
                });

                if (!this.ready) {
                    get_all_avatars.begin ();
                    this.ready = true;
                    this.set_widgets_sensitive (true);
                } else {
                    Media.get_avatar (this.home_list);
                }
                return false;
            });
        }

        private void get_older_mentions ()  {
            if (this.check_internet_connection ()) {
                this.api.get_older_mentions_timeline ();
            } else {
                this.switch_timeline ("error");
            }
        }

        public void update_older_mentions_ui () {
            Idle.add (() => {
                this.home_tmp.foreach ((tweet) => {
                    this.mentions_list.remove (tweet);
                });

                this.api.mentions_timeline.foreach ((tweet) => {
                    this.mentions_list.prepend (tweet, this);
                    this.db.add_user.begin (tweet.user_screen_name,
                        tweet.user_name, this.default_account_id);
                });

                if (!this.ready) {
                    get_all_avatars.begin ();
                    this.ready = true;
                    this.set_widgets_sensitive (true);
                } else {
                    Media.get_avatar (this.mentions_list);
                }
                return false;
            });
        }

        private void get_older_search ()  {
            if (this.check_internet_connection ()) {
                this.api.get_older_search_timeline (search_term);
            } else {
                this.switch_timeline ("error");
            }
        }

        public void update_older_search_ui () {
            Idle.add (() => {
                search_entry.text = search_term;

                this.api.search_timeline.foreach ((tweet) => {
                    this.search_list.prepend (tweet, this);
                });

                if (this.ready)
                    Media.get_avatar (this.search_list);

                return false;
            });
        }

        /*

        Indicator cleaning

        */

        private void clean_tweets_indicator () {
            #if HAVE_LIBMESSAGINGMENU
            this.indicator.clean_tweets_indicator();
            #endif
            this.unread_tweets = 0;
            #if HAVE_LIBUNITY
            this.launcher.set_count (get_total_unread ());
            #endif
        }

        private void clean_mentions_indicator () {
            #if HAVE_LIBMESSAGINGMENU
            this.indicator.clean_mentions_indicator();
            #endif
            this.unread_mentions = 0;
            #if HAVE_LIBUNITY
            this.launcher.set_count (get_total_unread ());
            #endif
        }

        private void clean_dm_indicator () {
            #if HAVE_LIBMESSAGINGMENU
            this.indicator.clean_dm_indicator();
            #endif
            this.unread_dm = 0;
            #if HAVE_LIBUNITY
            this.launcher.set_count (get_total_unread ());
            #endif
        }

        /*

        Callback method for sending messages

        */

        public void tweet_callback (string text, string id,
            string user_screen_name, bool dm, string media_uri) {

            int64 code;
            var text_url = "";
            var media_out = "";

            if (this.check_internet_connection ()) {
                if (dm)
                    if (media_uri == "")
                        code = this.api.send_direct_message (user_screen_name, text);
                    else
                        code = this.api.send_direct_message_with_media (user_screen_name, text, media_uri, out media_out);
                else
                    if (media_uri == "")
                        code = this.api.update (text, id);
                    else
                        code = this.api.update_with_media (text, id, media_uri, out media_out);

                if (code != 1) {
                    text_url = Utils.highlight_all (text);

                    if (media_out != "") {
                        text_url = text_url + " <a href='" + media_out + "'>" + media_out + "</a>";
                    }

                    string user = user_screen_name;

                    if ("@" in user_screen_name)
                        user = user.replace ("@", "");

                    if (user == "" || !dm)
                        user = this.api.account.screen_name;

                    Tweet tweet_tmp = new Tweet (code.to_string (), code.to_string (),
                        this.api.account.name, user, text_url, "", this.api.account.profile_image_url,
                        this.api.account.profile_image_file, false, false, dm);

                    if (dm) {
                        this.dm_sent_list.append (tweet_tmp, this);
                        this.switch_timeline ("dm");
                        Idle.add (() => {
                            this.notebook_dm.page = 1;
                            Media.get_avatar (this.dm_sent_list);
                            //Media.get_imgur_media (media_uri, null, this.dm_sent_list, tweet_tmp);
                            return false;
                        });
                    } else {
                        Idle.add (() => {
                            this.home_tmp.append (tweet_tmp);
                            this.home_list.append (tweet_tmp, this);
                            this.own_list.append (tweet_tmp, this);

                            Media.get_avatar (this.home_list);
                            Media.get_avatar (this.own_list);
                            Media.get_imgur_media (media_uri, null, this.home_list, tweet_tmp);
                            Media.get_imgur_media (media_uri, null, this.own_list, tweet_tmp);
                            return false;
                        });

                        this.switch_timeline ("home");
                    }
                }
            } else {
                this.switch_timeline ("error");
            }
        }

        public async void show_user () throws ThreadError {
            SourceFunc callback = show_user.callback;

            ThreadFunc<void*> run = () => {
                if (this.check_internet_connection ()) {
                    Idle.add (() => {
                        this.switch_timeline ("loading");
                        return false;
                    });

                    this.user_list.clear ();
                    this.api.get_user_timeline (user);
                } else {
                    this.switch_timeline ("error");
                }
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            yield;
        }

        public void update_user_timeline_ui () {
            Idle.add (() => {
                if (this.api.user_timeline.length () == 0) {
                    this.switch_timeline ("search");
                    return false;
                }

                this.user_box_info.update (this.api.user);
                Media.get_userbox_avatar (this.user_box_info);

                this.switch_timeline ("user");


                this.api.user_timeline.foreach ((tweet) => {
                    this.user_list.append (tweet, this);
                });

                if (this.ready) {
                    Media.get_avatar (this.user_list);
                    Idle.add (() => {
                        this.spinner.stop ();
                        return false;
                    });
                }

                return false;
            });
        }

        public void update_search_ui () {
            Idle.add (() => {
                this.switch_timeline ("search");

                search_entry.text = search_term;

                this.api.search_timeline.foreach ((tweet) => {
                    this.search_list.append (tweet, this);
                });

                if (this.ready) {
                    Media.get_avatar (this.search_list);
                    Idle.add (() => {
                        this.spinner.stop ();
                        this.scrolled_search.get_vadjustment().set_value(0);
                        return false;
                    });
                }

                return false;
            });
        }

        private async void show_search () throws ThreadError {
            SourceFunc callback = show_search.callback;

            ThreadFunc<void*> run = () => {
                if (search_term != "" && search_term[0] == '@' && !(" " in search_term) && !("%20" in search_term)) {
                    user = search_term.replace ("@", "");
                    this.show_user.begin ();
                    return null;
                }

                if (this.check_internet_connection ()) {
                    this.search_list.clear ();

                    Idle.add (() => {
                        this.switch_timeline ("loading");
                        search_entry.text = search_term;
                        return false;
                    });

                    this.api.get_search_timeline (search_term);
                } else {
                    this.switch_timeline ("error");
                }
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            yield;
        }

        public void update_list_ui () {
            Idle.add (() => {
                this.switch_timeline ("list");

                this.api.list_timeline.foreach ((tweet) => {
                    this.list_list.append (tweet, this);
                });

                if (this.ready)
                    Media.get_avatar (this.list_list);

                this.spinner.stop ();

                return false;
            });
        }

        private async void show_list () throws ThreadError {
            SourceFunc callback = show_list.callback;

            ThreadFunc<void*> run = () => {
                if (this.check_internet_connection ()) {
                    this.list_list.clear ();
                    this.list_list.list_id = list_id;
                    this.list_list.list_owner = list_owner;

                    Idle.add (() => {
                        this.switch_timeline ("loading");
                        return false;
                    });

                    this.api.get_list_timeline (list_id);
                } else {
                    this.switch_timeline ("error");
                }
                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);
            yield;
        }

        private bool check_internet_connection() {
            if (!Utils.check_internet_connection ()) {
                return false;
            }
            return true;
        }
    }
}
