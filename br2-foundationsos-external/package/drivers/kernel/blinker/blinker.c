/*
 * Demonstration of timer handling in linux
 * in a driver module
 * A driver module sets up a timer for operating
 * a device periodically.
 */

#include <linux/module.h>
#include <linux/timer.h>
#include <linux/platform_device.h>
#include <linux/gpio.h>
#include <linux/string.h>
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Driver for blinking devices");

#define BLINKER_DRIVER_NAME "bln"

static int gpio_out_pin = 17;
//static bool invert = 0;

static int limit = 5;
module_param(limit, int, 0);
MODULE_PARM_DESC(limit, "wakeup limit");

static unsigned int interval = 2;

static struct timer_list blinktimer;
static int counter = 0;

struct gpio_chip *gpiochip;

#define secs_to_jiffies(i)	(msecs_to_jiffies((i)*1000))


static int is_right_chip(struct gpio_chip *chip, void *data)
{
	printk("is_right_chip %s %d\n", chip->label, strcmp(data, chip->label));

	if (strcmp(data, chip->label) == 0)
		return 1;
	return 0;
}

static void blink_timeout(unsigned long dummy)
{
	static bool level = 0;

	counter++;
	level = 1 - level; /* flip state */

	pr_devel("bln: wakeup count %d, level %d\n", counter, level);
	gpiochip->set(gpiochip, gpio_out_pin, level);
	
	if (counter <= limit)
		mod_timer(&blinktimer, jiffies+secs_to_jiffies(interval));
	else
		pr_info("bln: wakeup limit reached\n");
}

static int blink_probe(struct platform_device *pdev)
{
	pr_devel("bln: probing %s id %d\n", pdev->name, pdev->id);
	return 0;
}

static int blink_remove(struct platform_device *pdev)
{
	pr_devel("bln: removing %s id %d\n", pdev->name, pdev->id);
	return 0;
}

static struct of_device_id of_blink_match[] = {
	{ .compatible	= "blink,led", },
	{ .compatible	= "blinker", },
	{ .compatible	= "bln", },
	{},
};
MODULE_DEVICE_TABLE(of, of_blink_match);

static struct platform_driver blink_driver = {
	.probe  = blink_probe,
	.remove = blink_remove,
	.driver = {
		.name = BLINKER_DRIVER_NAME,
		.owner = THIS_MODULE,
		.of_match_table = of_blink_match,
	}
};
//module_platform_driver(blink_driver);


static int __init blink_load(void)
{
	int err;
	//gpiochip = gpiochip_find("bcm2708_gpio",is_right_chip);
	if(!gpiochip)
	{
		gpiochip = gpiochip_find("pinctrl-bcm2835", is_right_chip);
	}
	if(!gpiochip)
	{
		pr_err("gpiochip not found\n");
	}
	gpiochip->direction_output(gpiochip, gpio_out_pin, 1);
	pr_devel("bln: loading limit=%d interval=%d\n", limit, interval);
	err = platform_driver_register(&blink_driver);
	if (unlikely(err)) {
		pr_err("bln: loading error %d...\n", err);
		return err;
	}
	setup_timer(&blinktimer, blink_timeout, 0);
	err = mod_timer(&blinktimer, secs_to_jiffies(interval));
	if (unlikely(err)) {
		pr_err("bln: timer error %d...\n", err);
		platform_driver_unregister(&blink_driver);
		del_timer(&blinktimer);
		return err;
	}
	return 0;
}
module_init(blink_load);

static void __exit blink_unload(void)
{
	int err;
	gpiochip->free(gpiochip,gpio_out_pin);
	pr_devel("bln: unloading limit=%d\n", limit);
	platform_driver_unregister(&blink_driver);
	err = del_timer(&blinktimer);
	if (err)
		pr_err("bln: timer delete error %d...\n", err);
}
module_exit(blink_unload);
