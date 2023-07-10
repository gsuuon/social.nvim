# social.nvim 📢

Browse recent github repos by topic

## Usage
`:Social [date] [topic]` — Show repos with the given topic created after a date. Date can be one of: `today`, `week`, `month`, `quarter`, `half`, `year`, or a string (YYYY-MM-DD). Defaults to `:Social today neovim`.

In the repo view buffer `<CR>` on `readme` to get a preview of the readme, or on `discussions` to get a link that you can `gx` to. To view a repo on github just use `gx` on it's url.
