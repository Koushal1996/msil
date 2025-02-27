import { Component, OnInit } from '@angular/core';

declare const $: any;

@Component({
    selector: 'app-fixedplugin-cmp',
    templateUrl: 'fixedplugin.component.html'
})

export class FixedPluginComponent implements OnInit {
    ngOnInit() {
        const $sidebar = $('.sidebar');
        const $off_canvas_sidebar = $('.off-canvas-sidebar');
        const window_width = $(window).width();

        if (window_width > 767) {
            if ($('.fixed-plugin .dropdown').hasClass('show-dropdown')) {
                $('.fixed-plugin .dropdown').addClass('open');
            }

        }

        $('.fixed-plugin a').click(function (event) {
            if ($(this).hasClass('switch-trigger')) {
                if (event.stopPropagation) {
                    event.stopPropagation();
                } else if (window.event) {
                    window.event.cancelBubble = true;
                }
            }
        });

        $('.fixed-plugin .background-color span').click(function () {
            $(this).siblings().removeClass('active');
            $(this).addClass('active');

            const new_color = $(this).data('color');

            if ($sidebar.length !== 0) {
                $sidebar.attr('data-background-color', new_color);
            }

            if ($off_canvas_sidebar.length !== 0) {
                $off_canvas_sidebar.attr('data-background-color', new_color);
            }
        });

        $('.fixed-plugin .active-color span').click(function () {
            $(this).siblings().removeClass('active');
            $(this).addClass('active');

            const new_color = $(this).data('color');

            if ($sidebar.length !== 0) {
                $sidebar.attr('data-active-color', new_color);
            }

            if ($off_canvas_sidebar.length !== 0) {
                $off_canvas_sidebar.attr('data-active-color', new_color);
            }
        });
    }
}
