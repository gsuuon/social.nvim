# social.nvim

Browse github repos by topic and recency

## Requirements
- recent neovim
- curl

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
- to view a repo on github hit enter on the line with the url (or you can gx the url)
- you can paginate to the previous interval if you used one of the named date spans (hit enter on previous or next)

You can hit enter on some items:
- `readme` — get a preview of the readme
- `discussion` — open the discussions
- `owner/repo` — additional info about the creator

## Motivation
To make it easy to discover github repos right from neovim. I'd also like to experiment with using github repos as technical blogs with folder structure - one could write an engineering blog post as a github repo where the main article goes in readme.md. Add the 'blog' topic to the repo and you have a buildable/executable blog post that's discoverable through social.nvim with `:Social week blog`.
