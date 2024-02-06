# social.nvim

Browse github repos by topic and recency.

## Usage
`:Social [date] [topic]` — Show repos with the given topic created after the date. Defaults to `:Social today neovim`.
  - `date` can be one of:
    - `today`
    - `week`
    - `month`
    - `quarter`
    - `half`
    - `year`
    - `YYYY-MM-DD`

In the Social view buffer:
- to view a repo on github just use `gx` on it's url

You can hit enter on some items:
- `readme` — get a preview of the readme
- `discussion` — get a link to the discussions that you can `gx` to.
- `owner/repo` — additional info about the creator
