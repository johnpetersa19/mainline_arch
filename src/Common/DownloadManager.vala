
using l_misc;

public class DownloadTask : GLib.Object {

	public Gee.ArrayList<DownloadItem> downloads;
	public string status_line = "";
	public int prg_count = 0;
	public bool is_running = false;

	public DownloadTask() {
		downloads = new Gee.ArrayList<DownloadItem>();
	}

	public void add_to_queue(DownloadItem item) {
		item.gid = "%06x".printf(Main.rnd.int_range(0,0xffffff));
		downloads.add(item);
	}

	public void execute() {
		is_running = true;
		prg_count = 0;
		status_line = "Starting downloads...";
		
		new Thread<void*>("download_thread", () => {
			int concurrent = App.concurrent_downloads > 0 ? App.concurrent_downloads : 4;
			
			try {
				var pool = new ThreadPool<DownloadItem>.with_owned_data((item) => {
					download_item_sync(item);
					prg_count++;
				}, concurrent, false);
				
				foreach (var item in downloads) {
					pool.add(item);
				}
				
				// wait for all downloads to finish
				ThreadPool.free((owned)pool, false, true);
			} catch (ThreadError e) {
				vprint("Thread error: " + e.message, 1, stderr);
			}
			
			is_running = false;
			return null;
		});
	}

	private void download_item_sync(DownloadItem item) {
		var session = new Soup.Session();
		session.timeout = App.connect_timeout_seconds > 0 ? App.connect_timeout_seconds : 15;
		if (App.user_agent.length > 0) {
			session.user_agent = App.user_agent;
		}

		var msg = new Soup.Message("GET", item.source_uri);

		try {
			var istream = session.send(msg, null);
			if (msg.status_code != 200) {
				vprint("HTTP Error " + msg.status_code.to_string() + " for " + item.source_uri, 1, stderr);
				return;
			}
			mkdir(item.download_dir);
			var file = File.new_for_path(item.download_dir + "/" + item.file_name);
			var ostream = file.replace(null, false, FileCreateFlags.NONE, null);
			
			int64 total = msg.response_headers.get_content_length();
			item.bytes_total = total > 0 ? total : 0;
			
			uint8[] buffer = new uint8[65536];
			ssize_t n;
			while ((n = istream.read(buffer)) > 0) {
				size_t bytes_written;
				ostream.write_all(buffer[0:n], out bytes_written, null);
				item.bytes_received += n;
				status_line = item.file_name + " " + item.bytes_received.to_string() + "/" + item.bytes_total.to_string();
			}
			ostream.close();
			istream.close();
		} catch (Error e) {
			vprint("Download error: " + e.message, 1, stderr);
			// limpar arquivo parcial
			var partial = File.new_for_path(item.download_dir + "/" + item.file_name);
			if (partial.query_exists()) {
				try { partial.delete(null); } catch {}
			}
		}
	}
}

public class DownloadItem : GLib.Object {
	public string source_uri = "";   // "https://archive.archlinux.org/packages/l/linux/linux-6.2.7.arch1-1-x86_64.pkg.tar.zst"
	public string download_dir = ""; // "/home/john/.cache/mainline/6.2.7/x86_64"
	public string file_name = "";    // "linux-6.2.7.arch1-1-x86_64.pkg.tar.zst"
	public string checksum = "";     // "sha-256=4a90d708984d6a8fab68411710be09aa2614fe1be5b5e054a872b155d15faab6"

	public string gid = "";          // first 6 bytes of gid
	public int64 bytes_total = -1;   // allow total=0 b/c server doesn't supply total for index.html
	public int64 bytes_received = 0;

	public DownloadItem(string uri = "", string destdir = "", string fname = "", string? cksum = "") {
		if (cksum==null) cksum = "";
		vprint("DownloadItem("+uri+","+destdir+","+fname+","+cksum+")",3);
		source_uri = uri;
		file_name = fname;
		download_dir = destdir;
		checksum = cksum;
	}
}
