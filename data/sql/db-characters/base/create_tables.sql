CREATE TABLE IF NOT EXISTS `custom_endless_storage` (
    `character_id` int(11) NOT NULL,
    `item_entry` int(11) NOT NULL,
    `item_subclass` int(11) NOT NULL,
    `item_class` int(11) NOT NULL,
    `amount` int(11) NOT NULL,
    PRIMARY KEY (`character_id`, `item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
